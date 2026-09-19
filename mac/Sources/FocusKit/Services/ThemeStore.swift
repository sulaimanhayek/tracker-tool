import Foundation

/// The list of themes, kept in themes.json. Only the names live here — every total
/// is derived from the session log, so the two files cannot disagree.
public final class ThemeStore: ObservableObject {
    @Published public var themes: [String] = [] {
        didSet { save() }
    }

    @Published public var selected: String? {
        didSet { UserDefaults.standard.set(selected, forKey: "selectedTheme") }
    }

    public init() {
        selected = UserDefaults.standard.string(forKey: "selectedTheme")
        load()
    }

    public func load() {
        guard
            let data = try? Data(contentsOf: DataFolder.themesFile),
            let saved = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        themes = saved
        if let selected, !themes.contains(selected) { self.selected = nil }
    }

    public func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !themes.contains(trimmed) else { return }
        themes.append(trimmed)
        if selected == nil { selected = trimmed }
    }

    public func remove(_ name: String) {
        themes.removeAll { $0 == name }
        if selected == name { selected = nil }
    }

    private func save() {
        DataFolder.ensureExists()
        guard let data = try? JSONEncoder().encode(themes) else { return }
        try? data.write(to: DataFolder.themesFile, options: .atomic)
    }
}
