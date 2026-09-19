import FocusKit
import SwiftUI

struct TimerView: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var themes: ThemeStore

    @State private var showingDurations = false
    @State private var newTheme = ""

    var body: some View {
        VStack(spacing: 26) {
            Picker("", selection: Binding(get: { timer.mode }, set: { timer.select($0) })) {
                ForEach(TimerMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

            ZStack {
                RingView(progress: timer.progress, tint: tint)
                    .frame(width: 280, height: 280)

                VStack(spacing: 8) {
                    Text(clock)
                        .font(.system(size: 54, weight: .light, design: .rounded))
                        .monospacedDigit()

                    Text(themes.selected ?? "No theme selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button(timer.isRunning ? "Pause" : "Start") { timer.toggle() }
                            .keyboardShortcut(.space, modifiers: [])
                            .buttonStyle(.borderedProminent)
                            .tint(tint)

                        Button("Reset") { timer.reset() }
                            .disabled(!timer.isRunning && timer.remaining == timer.total)
                    }
                    .padding(.top, 4)
                }
            }

            themePicker

            DisclosureGroup("Durations", isExpanded: $showingDurations) {
                HStack(spacing: 16) {
                    ForEach(TimerMode.allCases) { mode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Stepper(
                                value: Binding(
                                    get: { timer.durations[mode] ?? mode.defaultMinutes },
                                    set: {
                                        timer.durations[mode] = max(1, min(480, $0))
                                        timer.applyDurationChange()
                                    }
                                ),
                                in: 1...480
                            ) {
                                Text("\(timer.durations[mode] ?? mode.defaultMinutes) min")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 420)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var tint: Color {
        switch timer.mode {
        case .focus: return Color(red: 0.95, green: 0.43, blue: 0.36)
        case .shortBreak: return Color(red: 0.31, green: 0.78, blue: 0.60)
        case .longBreak: return Color(red: 0.36, green: 0.62, blue: 0.95)
        }
    }

    private var clock: String {
        let seconds = Int(timer.remaining.rounded())
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you working on today?")
                .font(.headline)

            HStack {
                TextField("Add a theme — e.g. Deep work, Writing, Research", text: $newTheme)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTheme)
                Button("Add", action: addTheme)
                    .disabled(newTheme.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if themes.themes.isEmpty {
                Text("No themes yet. Name one to start tracking where your focus goes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // A wrapping row of themes; the selected one is what the session log
                // records against.
                FlowLayout(spacing: 8) {
                    ForEach(themes.themes, id: \.self) { theme in
                        Button {
                            themes.selected = themes.selected == theme ? nil : theme
                        } label: {
                            HStack(spacing: 6) {
                                Text(theme)
                                Button {
                                    themes.remove(theme)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .help("Remove theme")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(themes.selected == theme ? tint : .secondary)
                    }
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func addTheme() {
        themes.add(newTheme)
        newTheme = ""
    }
}
