import AppKit
import Foundation

/// Where the app keeps its files. One folder, plain formats, no database — the
/// point is that everything stays readable without this app.
public enum DataFolder {
    private static let overrideKey = "dataFolderPath"

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

    public static func reveal() {
        ensureExists()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
