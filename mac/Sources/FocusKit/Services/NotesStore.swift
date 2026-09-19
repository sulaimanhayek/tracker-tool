import AppKit
import Combine
import Foundation

/// The sticky-notes board, backed by a folder of Word documents.
///
/// One note is one .doc file, named after the moment it was created. Where a note
/// sits on the board is furniture rather than content, so it lives separately in
/// board.json: delete that and you lose an arrangement, never a word.
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
    private var pendingWrites: [String: DispatchWorkItem] = [:]
    private var pendingLayoutSave: DispatchWorkItem?

    public init() {
        selectedFolder = UserDefaults.standard.string(forKey: "selectedNotesFolder") ?? "Board"
        reload()

        // A note being typed when the app quits must still reach its file.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flush()
        }
    }

    // MARK: - Folders

    public func reload() {
        loadFolders()
        if !folders.contains(selectedFolder) {
            selectedFolder = folders.first ?? "Board"
        }
        loadNotes()
    }

    private func loadFolders() {
        let manager = FileManager.default
        try? manager.createDirectory(at: DataFolder.notesFolder, withIntermediateDirectories: true)

        let contents = (try? manager.contentsOfDirectory(
            at: DataFolder.notesFolder,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []

        folders = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()

        if folders.isEmpty {
            // A board is only ever created on disk once there is something in it.
            folders = [selectedFolder]
        }
    }

    public func addFolder(_ name: String) {
        let trimmed = sanitise(name)
        guard !trimmed.isEmpty else { return }
        try? FileManager.default.createDirectory(at: url(forFolder: trimmed), withIntermediateDirectories: true)
        loadFolders()
        selectedFolder = trimmed
    }

    public func renameFolder(_ name: String) {
        let trimmed = sanitise(name)
        guard !trimmed.isEmpty, trimmed != selectedFolder else { return }
        let source = url(forFolder: selectedFolder)
        if FileManager.default.fileExists(atPath: source.path) {
            try? FileManager.default.moveItem(at: source, to: url(forFolder: trimmed))
        }
        loadFolders()
        selectedFolder = trimmed
    }

    /// Moves the folder to the Trash rather than deleting it, because the notes in it
    /// are the user's documents.
    public func trashFolder() {
        guard folders.count > 1 else { return }
        let target = url(forFolder: selectedFolder)
        try? FileManager.default.trashItem(at: target, resultingItemURL: nil)
        let remaining = folders.filter { $0 != selectedFolder }
        loadFolders()
        selectedFolder = remaining.first ?? folders.first ?? "Board"
    }

    /// Strips anything that cannot be a folder name, since the name is a real one.
    private func sanitise(_ name: String) -> String {
        name
            .components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func url(forFolder folder: String) -> URL {
        DataFolder.notesFolder.appendingPathComponent(folder, isDirectory: true)
    }

    private var boardFile: URL {
        url(forFolder: selectedFolder).appendingPathComponent("board.json")
    }

    // MARK: - Notes

    private func loadNotes() {
        let folder = url(forFolder: selectedFolder)
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".\(NoteDocument.fileExtension)") && !$0.hasPrefix(".") }
            .sorted()

        let layouts = loadLayouts()
        var loaded: [Note] = []

        for (index, file) in files.enumerated() {
            let created = NoteDocument.date(fromFilename: file) ?? Date()
            let html = (try? String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)) ?? ""
            let layout = layouts[file]

            loaded.append(Note(
                id: file,
                createdAt: created,
                text: NoteDocument.text(fromHTML: html),
                // A note whose layout is missing — dropped in by hand, say — still
                // has to land somewhere sensible.
                x: layout?.x ?? Double(24 + (index % 4) * 264),
                y: layout?.y ?? Double(24 + (index / 4) * 264),
                width: layout?.width ?? Note.defaultSize.width,
                height: layout?.height ?? Note.defaultSize.height,
                color: layout?.color ?? NoteColor.all[index % NoteColor.all.count].key,
                z: layout?.z ?? index + 1
            ))
        }

        notes = loaded
        topZ = max(1, loaded.map(\.z).max() ?? 1)
        isStacked = false
    }

    public func add() -> Note? {
        let now = Date()
        var name = "\(NoteDocument.stamp(for: now)).\(NoteDocument.fileExtension)"
        var attempt = 2
        let folder = url(forFolder: selectedFolder)

        // Two notes made inside the same second must not share a filename.
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) {
            name = "\(NoteDocument.stamp(for: now))-\(attempt).\(NoteDocument.fileExtension)"
            attempt += 1
        }

        let index = notes.count
        topZ += 1
        let note = Note(
            id: name,
            createdAt: now,
            x: Double(24 + (index % 4) * 264),
            y: Double(24 + (index / 4) * 264),
            color: NoteColor.all[index % NoteColor.all.count].key,
            z: topZ
        )

        notes.append(note)
        write(note, immediately: true)
        saveLayouts()
        return note
    }

    public func update(_ note: Note, writeText: Bool) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
        if writeText { write(note, immediately: false) }
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

    /// To the Trash, not deleted — a note is a document.
    public func trash(_ note: Note) {
        flush(note.id)
        let file = url(forFolder: selectedFolder).appendingPathComponent(note.id)
        try? FileManager.default.trashItem(at: file, resultingItemURL: nil)
        notes.removeAll { $0.id == note.id }
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

    /// Text is written after a pause rather than on every keystroke, so a note is
    /// one document write per edit rather than one per character.
    private func write(_ note: Note, immediately: Bool) {
        pendingWrites[note.id]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let file = self.url(forFolder: self.selectedFolder).appendingPathComponent(note.id)
            do {
                try FileManager.default.createDirectory(
                    at: file.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let html = NoteDocument.html(text: note.text, createdAt: note.createdAt)
                try html.write(to: file, atomically: true, encoding: .utf8)
                self.lastError = nil
            } catch {
                self.lastError = "Could not write \(note.id): \(error.localizedDescription)"
            }
            self.pendingWrites[note.id] = nil
        }

        pendingWrites[note.id] = work
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

    /// Forces pending writes out, for quitting, for deleting and before compiling.
    public func flush(_ id: String? = nil) {
        if let work = pendingLayoutSave {
            work.cancel()
            pendingLayoutSave = nil
            saveLayouts()
        }

        let keys = id.map { [$0] } ?? Array(pendingWrites.keys)
        for key in keys {
            guard let work = pendingWrites[key] else { continue }
            work.cancel()
            pendingWrites[key] = nil
            if let note = notes.first(where: { $0.id == key }) {
                let file = url(forFolder: selectedFolder).appendingPathComponent(note.id)
                let html = NoteDocument.html(text: note.text, createdAt: note.createdAt)
                try? html.write(to: file, atomically: true, encoding: .utf8)
            }
        }
    }

    private func loadLayouts() -> [String: NoteLayout] {
        guard
            let data = try? Data(contentsOf: boardFile),
            let saved = try? JSONDecoder().decode([String: NoteLayout].self, from: data)
        else { return [:] }
        return saved
    }

    private func saveLayouts() {
        let layouts = notes.reduce(into: [String: NoteLayout]()) { result, note in
            result[note.id] = NoteLayout(
                x: note.x, y: note.y, width: note.width, height: note.height,
                color: note.color, z: note.z
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layouts) else { return }
        try? FileManager.default.createDirectory(
            at: url(forFolder: selectedFolder),
            withIntermediateDirectories: true
        )
        try? data.write(to: boardFile, options: .atomic)
    }

    /// Compiles the folder into one document beside it, and returns where it landed.
    @discardableResult
    public func compileFolder() -> URL? {
        flush()
        guard !notes.isEmpty else { return nil }
        let name = "\(selectedFolder) \(NoteDocument.stamp(for: Date())).\(NoteDocument.fileExtension)"
        let file = DataFolder.notesFolder.appendingPathComponent(name)
        let html = NoteDocument.compiled(notes: notes, folder: selectedFolder)
        do {
            try html.write(to: file, atomically: true, encoding: .utf8)
            lastError = nil
            return file
        } catch {
            lastError = "Could not write \(name): \(error.localizedDescription)"
            return nil
        }
    }
}
