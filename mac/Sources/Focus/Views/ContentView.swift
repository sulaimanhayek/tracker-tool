import FocusKit
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case timer, stats

    var id: String { rawValue }
    var label: String { self == .timer ? "Timer" : "Insights" }
    var symbol: String { self == .timer ? "timer" : "chart.bar" }
}

struct ContentView: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var log: SessionLog
    @ObservedObject var themes: ThemeStore

    @State private var page: Page = .timer

    var body: some View {
        VStack(spacing: 0) {
            // The timer keeps running whichever page is showing; only the view changes.
            switch page {
            case .timer: TimerView(timer: timer, themes: themes)
            case .stats: StatsView(log: log)
            }

            if let error = log.lastError {
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
                .frame(width: 200)
            }
        }
        .frame(minWidth: 520, minHeight: 640)
    }
}
