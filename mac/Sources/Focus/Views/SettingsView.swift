import FocusKit
import SwiftUI

extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// Everything adjustable in one place: how long a stretch runs, what the app
/// looks like, and where the files go.
struct SettingsView: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var backgrounds: BackgroundStore

    var onChangeFolder: (URL, Bool) -> Void

    var body: some View {
        TabView {
            DurationsSettings(timer: timer)
                .tabItem { Label("Timer", systemImage: "timer") }
            AppearanceSettings(backgrounds: backgrounds)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            StorageSettings(onChangeFolder: onChangeFolder)
                .tabItem { Label("Storage", systemImage: "folder") }
        }
        .frame(width: 480)
        .padding(20)
    }
}

/// How long each stretch runs. Changing the mode you are sitting in re-reads the
/// deadline, so an edit takes effect now rather than next round.
private struct DurationsSettings: View {
    @ObservedObject var timer: TimerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How long is a stretch?")
                .font(.headline)

            ForEach(TimerMode.allCases) { mode in
                DurationRow(timer: timer, mode: mode)
            }

            Text("Type a number of minutes or use the arrows. A change to the stretch you are in now takes effect straight away; time already banked is kept.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 8)
    }
}

/// One mode's length, typed or nudged.
///
/// The field keeps its own text while it is being typed — a binding straight to
/// the number would fight the keyboard, rewriting "6" to 6 before "60" is
/// finished. It is read back when you press Return or leave the field, and
/// anything that is not a usable number falls back to what was there.
private struct DurationRow: View {
    @ObservedObject var timer: TimerModel
    let mode: TimerMode

    @State private var text = ""
    @FocusState private var typing: Bool

    private var minutes: Int { timer.durations[mode] ?? mode.defaultMinutes }

    var body: some View {
        HStack(spacing: 8) {
            Text(mode.label)
                .frame(width: 110, alignment: .leading)

            TextField("", text: $text)
                .focused($typing)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 58)
                .onSubmit(commit)
                .onChange(of: typing) { _, isTyping in
                    // Leaving the field counts as agreeing with what is in it.
                    if isTyping { text = String(minutes) } else { commit() }
                }

            Text("min")
                .foregroundStyle(.secondary)

            Stepper("", value: Binding(get: { minutes }, set: { set($0) }), in: 1...480)
                .labelsHidden()

            Spacer()

            Button("Reset") { set(mode.defaultMinutes) }
                .buttonStyle(.link)
                .disabled(minutes == mode.defaultMinutes)
        }
        .onAppear { text = String(minutes) }
        // The arrows and Reset write the number, so the field follows them.
        .onChange(of: minutes) { _, value in
            if !typing { text = String(value) }
        }
    }

    private func commit() {
        let digits = text.trimmingCharacters(in: .whitespaces)
        guard let typed = Int(digits), typed > 0 else {
            text = String(minutes)
            return
        }
        set(typed)
        text = String(timer.durations[mode] ?? minutes)
    }

    private func set(_ value: Int) {
        timer.durations[mode] = max(1, min(480, value))
        timer.applyDurationChange()
    }
}

/// The background. The same six the web app offers, each a whole palette so a
/// light background still reads.
private struct AppearanceSettings: View {
    @ObservedObject var backgrounds: BackgroundStore

    private let columns = [GridItem(.adaptive(minimum: 128), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Background")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Background.all) { background in
                    Button {
                        backgrounds.selected = background.key
                    } label: {
                        swatch(background)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Chosen once and remembered; the notes board and the rest of the app follow it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 8)
    }

    /// A small picture of the palette rather than a colour name — the point is
    /// how it looks, so show it.
    private func swatch(_ background: Background) -> some View {
        let isSelected = backgrounds.selected == background.key

        return VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color(background.background)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(background.surface))
                    .frame(height: 22)
                    .padding(8)
            }
            .frame(height: 62)

            Text(background.label)
                .font(.caption)
                .foregroundStyle(Color(background.text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(background.surface))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color(background.border),
                        lineWidth: isSelected ? 2.5 : 1)
        }
    }
}

/// Where the files live, shown as the directory it is rather than described.
private struct StorageSettings: View {
    var onChangeFolder: (URL, Bool) -> Void

    @AppStorage(DataFolder.overrideKey) private var overridePath: String = ""
    @State private var moveExisting = true
    @State private var entries: [DataFolder.Entry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data folder")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)
                Text(DataFolder.url.abbreviatedPath)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            directory

            Toggle("Move my existing data to the new folder", isOn: $moveExisting)
                .font(.caption)
                .toggleStyle(.checkbox)

            HStack(spacing: 10) {
                Button("Change…") {
                    guard let url = DataFolderPicker.run(prompt: "Use This Folder") else { return }
                    onChangeFolder(url, moveExisting)
                    load()
                }
                Button("Reveal in Finder") { DataFolder.reveal() }
                Button("Refresh") { load() }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 8)
        .onAppear(perform: load)
        // The path is read off DataFolder, so a change behind it redraws this.
        .id(overridePath)
    }

    /// The folder's actual contents, a level deep. Nothing is written to show
    /// this, and an empty folder says so rather than looking broken.
    private var directory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                if entries.isEmpty {
                    Text("Empty for now — the files appear as you use the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(entries) { entry in
                    row(entry, indent: 0)
                    ForEach(entry.children) { child in
                        row(child, indent: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(height: 150)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        }
    }

    private func row(_ entry: DataFolder.Entry, indent: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: entry.isDirectory ? "folder" : "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.name)
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.leading, CGFloat(indent) * 18)
    }

    private func load() {
        entries = DataFolder.isChosen ? DataFolder.listing() : []
    }
}
