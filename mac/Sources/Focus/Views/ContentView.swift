import FocusKit
import SwiftUI

extension Notification.Name {
    /// Posted by the menu command, so adding time by hand is one keystroke from
    /// any page rather than only from Insights.
    static let addManualTime = Notification.Name("addManualTime")
}

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
    // Not observed here: only the timer page redraws as the clock ticks, not
    // the notes board or the charts.
    let timer: TimerModel
    @ObservedObject var log: SessionLog
    @ObservedObject var themes: ThemeStore
    @ObservedObject var notes: NotesStore
    @EnvironmentObject var backgrounds: BackgroundStore

    var onChangeFolder: (URL, Bool) -> Void

    @State private var page: Page = .timer
    @State private var sheet: Sheet? = DataFolder.isChosen ? nil : .welcome

    /// The two things that interrupt the window. One sheet modifier, because
    /// SwiftUI honours only one per view.
    private enum Sheet: String, Identifiable {
        case welcome, addTime
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // The timer keeps running whichever page is showing; only the view changes.
            switch page {
            case .timer: TimerView(timer: timer, themes: themes)
            case .notes: NotesView(store: notes)
            case .stats:
                StatsView(log: log, onChangeFolder: onChangeFolder) { sheet = .addTime }
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
        .onReceive(NotificationCenter.default.publisher(for: .addManualTime)) { _ in
            sheet = .addTime
        }
        // Asked once, on the very first launch; the answer can be changed
        // later from Insights.
        .sheet(item: $sheet) { which in
            switch which {
            case .welcome:
                WelcomeSheet { url, moveExisting in
                    onChangeFolder(url, moveExisting)
                    sheet = nil
                }
            case .addTime:
                // Time worked away from the timer, typed in after the fact.
                ManualEntrySheet(log: log, themes: themes) { sheet = nil }
            }
        }
    }
}
