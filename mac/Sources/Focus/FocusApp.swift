import FocusKit
import SwiftUI

@main
struct FocusApp: App {
    @StateObject private var log: SessionLog
    @StateObject private var themes: ThemeStore
    @StateObject private var timer: TimerModel

    init() {
        DataFolder.ensureExists()
        let log = SessionLog()
        let themes = ThemeStore()
        _log = StateObject(wrappedValue: log)
        _themes = StateObject(wrappedValue: themes)
        _timer = StateObject(wrappedValue: TimerModel(log: log, themes: themes))
    }

    var body: some Scene {
        Window("Focus", id: "main") {
            ContentView(timer: timer, log: log, themes: themes)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Reveal Data Folder in Finder") { DataFolder.reveal() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Reload Sessions from Disk") { log.load() }
            }
        }
    }
}
