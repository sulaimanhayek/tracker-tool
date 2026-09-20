import FocusKit
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case timer, notes, stats

    var id: String { rawValue }

    var label: String {
        switch self {
        case .timer: return "Timer"
        case .notes: return "Notes"
        case .stats: return "Insights"
        }
    }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .notes: return "note.text"
        case .stats: return "chart.bar"
        }
    }
}

struct ContentView: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var log: SessionLog
    @ObservedObject var themes: ThemeStore
    @ObservedObject var notes: NotesStore
    @EnvironmentObject var backgrounds: BackgroundStore

    var onChangeFolder: (URL, Bool) -> Void

    @State private var page: Page = .timer
    @State private var asking = !DataFolder.isChosen

    var body: some View {
        VStack(spacing: 0) {
            // The timer keeps running whichever page is showing; only the view changes.
            switch page {
            case .timer: TimerView(timer: timer, themes: themes)
            case .notes: NotesView(store: notes)
            case .stats: StatsView(log: log, onChangeFolder: onChangeFolder)
            }

            if let error = log.lastError ?? notes.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $page) {
                    ForEach(Page.allCases) { page in
                        Label(page.label, systemImage: page.symbol).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }

            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Settings — durations, background, data folder")
            }
        }
        // One palette for the whole app: the hue behind everything, and the
        // light/dark scheme it belongs to, so system colours match it.
        .background(Color(backgrounds.current.background))
        .preferredColorScheme(backgrounds.current.isDark ? .dark : .light)
        .frame(minWidth: 720, minHeight: 680)
        // Asked once, on the very first launch; the answer can be changed
        // later from Insights.
        .sheet(isPresented: $asking) {
            WelcomeSheet { url, moveExisting in
                onChangeFolder(url, moveExisting)
                asking = false
            }
        }
    }
}
