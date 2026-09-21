import FocusKit
import SwiftUI

@main
struct FocusApp: App {
    @StateObject private var log: SessionLog
    @StateObject private var themes: ThemeStore
    // Held, not observed, so the app's scenes are not rebuilt every second.
    @State private var timer: TimerModel
    @StateObject private var notes = NotesStore()
    @StateObject private var backgrounds = BackgroundStore()
    @AppStorage("soundsEnabled") private var soundsEnabled = true

    init() {
        // Nothing is written until the folder question has been answered, so a
        // first launch cannot leave a stray folder behind if the user picks
        // somewhere else.
        if DataFolder.isChosen { DataFolder.ensureExists() }
        let log = SessionLog()
        let themes = ThemeStore()
        _log = StateObject(wrappedValue: log)
        _themes = StateObject(wrappedValue: themes)
        _timer = State(initialValue: TimerModel(log: log, themes: themes))
    }

    /// Points the app at another folder and re-reads everything from there.
    private func changeFolder(to url: URL, movingExisting: Bool) {
        notes.flush()
        do {
            try DataFolder.relocate(to: url, movingExisting: movingExisting)
        } catch {
            log.report("Could not use that folder: \(error.localizedDescription)")
            return
        }
        log.load()
        themes.load()
        notes.reload()
    }

    var body: some Scene {
        Window("Focus", id: "main") {
            ContentView(timer: timer, log: log, themes: themes, notes: notes) { url, moveExisting in
                changeFolder(to: url, movingExisting: moveExisting)
            }
            .environmentObject(backgrounds)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Reveal Data Folder in Finder") { DataFolder.reveal() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Reload from Disk") {
                    log.load()
                    themes.load()
                    notes.reload()
                }
                Toggle("Play Sounds", isOn: $soundsEnabled)
                Button("Change Data Folder…") {
                    if let url = DataFolderPicker.run(prompt: "Use This Folder") {
                        changeFolder(to: url, movingExisting: true)
                    }
                }
            }
        }

        // ⌘, and Focus → Settings…, plus the gear in the toolbar.
        Settings {
            SettingsView(timer: timer, backgrounds: backgrounds) { url, moveExisting in
                changeFolder(to: url, movingExisting: moveExisting)
            }
        }
    }
}
