import AppKit
import Combine
import Foundation

/// The sticky-notes board, backed by one Word document per board.
///
/// `notes/Board.doc` holds every note on that board, oldest first, one section
/// each. Where a note sits on the board is furniture rather than content, so it
/// lives separately in `notes/Board.json`: delete that and you lose an
/// arrangement, never a word.
public final class NotesStore: ObservableObject {
    @Published public private(set) var folders: [String] = []
    @Published public private(set) var notes: [Note] = []
    @Published public var selectedFolder: String = "Board" {
        didSet {
            guard selectedFolder != oldValue else { return }
            UserDefaults.standard.set(selectedFolder, forKey: "selectedNotesFolder")
            loadNotes()
        }
    }
    @Published public var isStacked = false
    @Published public private(set) var lastError: String?

    private var topZ = 1
    private var pendingWrite: DispatchWorkItem?
    private var pendingLayoutSave: DispatchWorkItem?

    public init() {
        selectedFolder = UserDefaults.standard.string(forKey: "selectedNotesFolder") ?? "Board"
        reload()

        // A note being typed when the app quits must still reach its document.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flush()
        }
    }

    // MARK: - Boards

    public func reload() {
        // Until the user has said where their data goes, nothing is read and
        // nothing is created.
        guard DataFolder.isChosen else {
            folders = [selectedFolder]
            notes = []
            return
        }
        migrateFolders()
        loadFolders()
        if !folders.contains(selectedFolder) {
            selectedFolder = folders.first ?? "Board"
        }
        loadNotes()
    }

    private func loadFolders() {
        let manager = FileManager.default
        try? manager.createDirectory(at: DataFolder.notesFolder, withIntermediateDirectories: true)

        let contents = (try? manager.contentsOfDirectory(atPath: DataFolder.notesFolder.path)) ?? []
        folders = contents
            .filter { $0.hasSuffix(".\(NoteDocument.fileExtension)") && !$0.hasPrefix(".") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()

        if folders.isEmpty {
            // A board is only ever created on disk once there is something in it.
            folders = [selectedFolder]
        }
    }

    /// Earlier versions kept a folder per board and a document per note. Those are
    /// folded into a single document the first time they are seen; the old folder
    /// is left exactly where it is rather than deleted, so nothing is taken away
    /// on the strength of a format change.
    private func migrateFolders() {
        let manager = FileManager.default
        let root = DataFolder.notesFolder
        let contents = (try? manager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []

        for folder in contents {
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let name = folder.lastPathComponent
            let destination = documentURL(forFolder: name)
            guard !manager.fileExists(atPath: destination.path) else { continue }

            let files = ((try? manager.contentsOfDirectory(atPath: folder.path)) ?? [])
                .filter { $0.hasSuffix(".\(NoteDocument.fileExtension)") && !$0.hasPrefix(".") }
                .sorted()
            guard !files.isEmpty else { continue }

            let oldLayouts = layouts(at: folder.appendingPathComponent("board.json"))
            var carried: [Note] = []
            var moved: [String: NoteLayout] = [:]

            for (index, file) in files.enumerated() {
                let html = (try? String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)) ?? ""
                let created = legacyDate(fromFilename: file) ?? Date()
                let text = NoteDocument.notes(fromHTML: html, fallbackDate: created, titleTag: "h1").first?.text ?? ""
                let id = NoteDocument.stamp(for: created)
                carried.append(Note(id: id, createdAt: created, text: text))
                if let layout = oldLayouts[file] { moved[id] = layout }
                _ = index
            }

            try? NoteDocument.board(notes: carried, name: name)
                .write(to: destination, atomically: true, encoding: .utf8)
            save(layouts: moved, to: layoutURL(forFolder: name))
        }
    }

    /// The old per-note filename, `2026-09-19_21-25-54.doc`.
    private func legacyDate(fromFilename name: String) -> Date? {
        let base = (name as NSString).deletingPathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: String(base.prefix(19)))
    }

    public func addFolder(_ name: String) {
        let trimmed = sanitise(name)
        guard !trimmed.isEmpty else { return }
        selectedFolder = trimmed
        writeDocument(immediately: true)
        loadFolders()
    }

    public func renameFolder(_ name: String) {
        let trimmed = sanitise(name)
        guard !trimmed.isEmpty, trimmed != selectedFolder else { return }
        flush()
        let manager = FileManager.default
        try? manager.moveItem(at: documentURL(forFolder: selectedFolder), to: documentURL(forFolder: trimmed))
        try? manager.moveItem(at: layoutURL(forFolder: selectedFolder), to: layoutURL(forFolder: trimmed))
        selectedFolder = trimmed
        // The board's own name is printed inside the document, so it is rewritten.
        writeDocument(immediately: true)
        loadFolders()
    }

    /// Moves the board to the Trash rather than deleting it, because the document
    /// in it is the user's.
    public func trashFolder() {
        guard folders.count > 1 else { return }
        pendingWrite?.cancel()
        pendingWrite = nil
        pendingLayoutSave?.cancel()
        pendingLayoutSave = nil

        let manager = FileManager.default
        try? manager.trashItem(at: documentURL(forFolder: selectedFolder), resultingItemURL: nil)
        try? manager.trashItem(at: layoutURL(forFolder: selectedFolder), resultingItemURL: nil)

        let remaining = folders.filter { $0 != selectedFolder }
        loadFolders()
        selectedFolder = remaining.first ?? folders.first ?? "Board"
    }

    /// Strips anything that cannot be a filename, since the board's name is one.
    private func sanitise(_ name: String) -> String {
        name
            .components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The Word document for a board — the file to open, reveal or back up.
    public func documentURL(forFolder folder: String) -> URL {
        DataFolder.notesFolder.appendingPathComponent("\(folder).\(NoteDocument.fileExtension)")
    }

    public func layoutURL(forFolder folder: String) -> URL {
        DataFolder.notesFolder.appendingPathComponent("\(folder).json")
    }

    // MARK: - Notes

    private func loadNotes() {
        let file = documentURL(forFolder: selectedFolder)
        let html = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        let parsed = NoteDocument.notes(fromHTML: html)
        let saved = layouts(at: layoutURL(forFolder: selectedFolder))

        notes = parsed.enumerated().map { index, item in
            let layout = saved[item.id]
            return Note(
                id: item.id,
                createdAt: item.createdAt,
                text: item.text,
                // A note whose layout is missing — typed into the document by
                // hand, say — still has to land somewhere sensible.
                x: layout?.x ?? Double(24 + (index % 4) * 264),
                y: layout?.y ?? Double(24 + (index / 4) * 264),
                width: layout?.width ?? Note.defaultSize.width,
                height: layout?.height ?? Note.defaultSize.height,
                color: layout?.color ?? NoteColor.all[index % NoteColor.all.count].key,
                z: layout?.z ?? index + 1
            )
        }

        topZ = max(1, notes.map(\.z).max() ?? 1)
        isStacked = false
    }

    public func add() -> Note? {
        let now = Date()
        var id = NoteDocument.stamp(for: now)
        var attempt = 2
        // Two notes made inside the same second must not share an identity.
        while notes.contains(where: { $0.id == id }) {
            id = "\(NoteDocument.stamp(for: now)) (\(attempt))"
            attempt += 1
        }

        let index = notes.count
        topZ += 1
        let note = Note(
            id: id,
            createdAt: now,
            x: Double(24 + (index % 4) * 264),
            y: Double(24 + (index / 4) * 264),
            color: NoteColor.all[index % NoteColor.all.count].key,
            z: topZ
        )

        notes.append(note)
        writeDocument(immediately: true)
        saveLayouts()
        return note
    }

    public func update(_ note: Note, writeText: Bool) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
        if writeText { writeDocument(immediately: false) }
        // Dragging changes the layout many times a second, so the board file is
        // written once things settle rather than once per frame.
        scheduleLayoutSave()
    }

    public func lift(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }), notes[index].z != topZ else { return }
        topZ += 1
        notes[index].z = topZ
        scheduleLayoutSave()
    }

    /// Removing a note rewrites the board's document without it. The document
    /// itself only ever goes to the Trash, never a single note.
    public func trash(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        writeDocument(immediately: true)
        saveLayouts()
    }

    /// Lays the board out in columns, each note collapsed to its first line.
    public func organise(boardHeight: Double) {
        let step = 72.0
        let gap = 24.0
        let perColumn = max(1, Int((boardHeight - gap) / step))
        let columnWidth = (notes.map(\.width).max() ?? Note.defaultSize.width) + gap

        for (index, _) in notes.enumerated() {
            notes[index].x = gap + Double(index / perColumn) * columnWidth
            notes[index].y = gap + Double(index % perColumn) * step
            notes[index].z = index + 1
        }

        topZ = max(1, notes.count)
        isStacked = true
        saveLayouts()
    }

    // MARK: - Files

    /// The document is written after a pause rather than on every keystroke, so
    /// editing a note is one write per edit rather than one per character.
    private func writeDocument(immediately: Bool) {
        pendingWrite?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let file = self.documentURL(forFolder: self.selectedFolder)
            do {
                try FileManager.default.createDirectory(
                    at: DataFolder.notesFolder,
                    withIntermediateDirectories: true
                )
                let html = NoteDocument.board(notes: self.notes, name: self.selectedFolder)
                try html.write(to: file, atomically: true, encoding: .utf8)
                self.lastError = nil
            } catch {
                self.lastError = "Could not write \(file.lastPathComponent): \(error.localizedDescription)"
            }
            self.pendingWrite = nil
        }

        pendingWrite = work
        if immediately {
            work.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
    }

    private func scheduleLayoutSave() {
        pendingLayoutSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveLayouts()
            self?.pendingLayoutSave = nil
        }
        pendingLayoutSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Forces pending writes out, for quitting, for switching boards and before
    /// anything that reads the files back.
    public func flush(_ id: String? = nil) {
        if let work = pendingLayoutSave {
            work.cancel()
            pendingLayoutSave = nil
            saveLayouts()
        }
        if let work = pendingWrite {
            // Performed first: a cancelled work item does nothing when performed,
            // and a work item only ever runs once, so the pending timer that
            // fires later is harmless.
            work.perform()
            pendingWrite = nil
        }
    }

    private func layouts(at url: URL) -> [String: NoteLayout] {
        guard
            let data = try? Data(contentsOf: url),
            let saved = try? JSONDecoder().decode([String: NoteLayout].self, from: data)
        else { return [:] }
        return saved
    }

    private func saveLayouts() {
        let current = notes.reduce(into: [String: NoteLayout]()) { result, note in
            result[note.id] = NoteLayout(
                x: note.x, y: note.y, width: note.width, height: note.height,
                color: note.color, z: note.z
            )
        }
        save(layouts: current, to: layoutURL(forFolder: selectedFolder))
    }

    private func save(layouts: [String: NoteLayout], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layouts) else { return }
        try? FileManager.default.createDirectory(at: DataFolder.notesFolder, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Writes everything out and returns the board's document, for revealing it.
    @discardableResult
    public func compileFolder() -> URL? {
        flush()
        let file = documentURL(forFolder: selectedFolder)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return file
    }
}
