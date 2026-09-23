import FocusKit
import SwiftUI

/// Adds focus time that happened without the timer — a morning's work started
/// before the app was open, a stretch away from the desk.
///
/// It writes the same row the timer writes, so nothing downstream has to know the
/// difference.
struct ManualEntrySheet: View {
    @ObservedObject var log: SessionLog
    @ObservedObject var themes: ThemeStore
    var onClose: () -> Void

    @State private var day = Date()
    @State private var startTime = ManualEntrySheet.defaultStart
    @State private var endTime = Date()
    @State private var theme: String
    @State private var newTheme = ""

    private let calendar = Calendar.current

    init(log: SessionLog, themes: ThemeStore, onClose: @escaping () -> Void) {
        self.log = log
        self.themes = themes
        self.onClose = onClose
        _theme = State(initialValue: themes.selected ?? themes.themes.first ?? "")
    }

    /// A morning's work is the case this exists for, so the sheet opens on one.
    private static var defaultStart: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var session: Session {
        ManualEntry.session(day: day, from: startTime, to: endTime, theme: theme, calendar: calendar)
    }

    private var problem: String? { ManualEntry.problem(with: session) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add time you did not track")
                    .font(.title2.weight(.semibold))
                Text("Worked without starting the timer? Put the hours in here and they count the same as any other session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Day")
                    DatePicker("", selection: $day, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                }
                GridRow {
                    Text("From")
                    HStack(spacing: 8) {
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("to")
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                GridRow {
                    Text("Theme")
                    themeField
                }
            }

            summary

            HStack {
                Button("Cancel", role: .cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add \(Statistics.format(seconds: session.seconds))") {
                    themes.add(theme)
                    log.append(session)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var themeField: some View {
        HStack(spacing: 8) {
            if themes.themes.isEmpty {
                TextField("e.g. Deep work", text: $newTheme)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: newTheme) { _, name in theme = name }
            } else {
                Picker("", selection: $theme) {
                    ForEach(themes.themes, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    if !themes.themes.contains(theme) {
                        Text(theme.isEmpty ? "No theme" : theme).tag(theme)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }
        }
    }

    /// What the entry adds up to, and anything about it worth saying before it is
    /// written — the log is append-only, so a row is easier to get right than to
    /// take back.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                Label(
                    "\(Statistics.format(seconds: session.seconds)) on \(dayLabel)",
                    systemImage: "checkmark.circle"
                )
                if let clash = log.firstOverlap(with: session) {
                    Text("Note: this covers time already logged (\(timeLabel(clash))). It will be counted twice.")
                        .foregroundStyle(.secondary)
                }
                if session.end.timeIntervalSince(session.start) > 0,
                   !calendar.isDate(session.end, inSameDayAs: session.start) {
                    Text("Ends after midnight, so it is logged on the day it started.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .frame(minHeight: 32, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: session.start)
    }

    private func timeLabel(_ session: Session) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: session.start))–\(formatter.string(from: session.end))"
    }
}
