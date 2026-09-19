import AppKit
import FocusKit
import SwiftUI

/// Asks the user where their data should live and re-points the app at it.
///
/// Everything the app writes lives in one folder, so choosing it is a single
/// decision rather than a setting per file.
enum DataFolderPicker {
    /// Shows the open panel. Returns the chosen folder, or nil if cancelled.
    static func run(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for your Focus data"
        panel.message = "Focus will keep your sessions, themes and notes in this folder."
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = DataFolder.url.deletingLastPathComponent()
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// The first-run question. Nothing is written to disk until it is answered.
struct WelcomeSheet: View {
    var onChoose: (URL, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where should Focus keep your data?")
                    .font(.title2.weight(.semibold))
                Text("Focus stores everything as plain files you can open yourself: a session log you can read in Numbers or Excel, and one Word document per note. Pick a folder in iCloud Drive or Dropbox if you want it on more than one Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("sessions.csv — every stretch you finish, appended", systemImage: "tablecells")
                Label("themes.json — the things you work on", systemImage: "tag")
                Label("notes/ — a Word document per sticky note", systemImage: "note.text")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("Choose Folder…") {
                    if let url = DataFolderPicker.run(prompt: "Use This Folder") {
                        onChoose(url, false)
                    }
                }

                Spacer()

                Button("Use \(DataFolder.defaultURL.abbreviatedPath)") {
                    onChoose(DataFolder.defaultURL, false)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460)
    }
}

/// The same choice again later, from Insights.
struct DataFolderSection: View {
    var onChange: (URL, Bool) -> Void

    @AppStorage(DataFolder.overrideKey) private var overridePath: String = ""
    @State private var moveExisting = true
    @State private var summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data folder")
                .font(.headline)

            Text(DataFolder.url.abbreviatedPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                // The path is read off DataFolder, so this redraws when the
                // preference behind it changes.
                .id(overridePath)

            Toggle("Move my existing data to the new folder", isOn: $moveExisting)
                .font(.caption)
                .toggleStyle(.checkbox)

            HStack(spacing: 10) {
                Button("Change…") {
                    guard let url = DataFolderPicker.run(prompt: "Use This Folder") else { return }
                    onChange(url, moveExisting)
                    summary = "Now using \(url.abbreviatedPath)."
                }
                Button("Reveal in Finder") { DataFolder.reveal() }
            }

            if let summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension URL {
    /// `~/Documents/Focus` rather than the full path — shorter and it avoids
    /// putting the account name on screen.
    var abbreviatedPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
