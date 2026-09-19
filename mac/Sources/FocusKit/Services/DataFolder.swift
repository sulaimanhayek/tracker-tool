import AppKit
import Foundation

/// Where the app keeps its files. One folder, plain formats, no database — the
/// point is that everything stays readable without this app.
public enum DataFolder {
    public static let overrideKey = "dataFolderPath"
    private static let chosenKey = "hasChosenDataFolder"

    /// Whether the user has been asked where their data should live. Until they
    /// have, the app has not written anything anywhere.
    public static var isChosen: Bool {
        UserDefaults.standard.bool(forKey: chosenKey)
    }

    public static func markChosen() {
        UserDefaults.standard.set(true, forKey: chosenKey)
    }

    public static var url: URL {
        if let path = UserDefaults.standard.string(forKey: overrideKey) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return defaultURL
    }

    public static var defaultURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Focus", isDirectory: true)
    }

    public static func setURL(_ url: URL?) {
        if let url {
            UserDefaults.standard.set(url.path, forKey: overrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: overrideKey)
        }
    }

    public static var sessionsFile: URL { url.appendingPathComponent("sessions.csv") }
    public static var themesFile: URL { url.appendingPathComponent("themes.json") }
    public static var notesFolder: URL { url.appendingPathComponent("notes", isDirectory: true) }

    @discardableResult
    public static func ensureExists() -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// What moving the folder did, so the app can say so rather than guess.
    public struct Relocation {
        public var moved: [String] = []
        public var kept: [String] = []

        public init() {}
    }

    /// Points the app at another folder, optionally bringing what is already there.
    ///
    /// Anything already present at the destination is left exactly as it is — a
    /// file is never overwritten here, so the worst case is two folders to tidy
    /// by hand rather than a note lost.
    @discardableResult
    public static func relocate(to destination: URL, movingExisting: Bool) throws -> Relocation {
        let manager = FileManager.default
        let source = url
        var result = Relocation()

        try manager.createDirectory(at: destination, withIntermediateDirectories: true)

        if movingExisting, source.standardizedFileURL != destination.standardizedFileURL {
            let items = (try? manager.contentsOfDirectory(atPath: source.path)) ?? []
            for item in items where !item.hasPrefix(".") {
                let to = destination.appendingPathComponent(item)
                guard !manager.fileExists(atPath: to.path) else {
                    result.kept.append(item)
                    continue
                }
                do {
                    try manager.moveItem(at: source.appendingPathComponent(item), to: to)
                    result.moved.append(item)
                } catch {
                    result.kept.append(item)
                }
            }
        }

        setURL(destination)
        markChosen()
        return result
    }

    public static func reveal() {
        ensureExists()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
