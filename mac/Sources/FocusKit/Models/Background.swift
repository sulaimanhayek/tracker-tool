import Foundation

public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `#12141a`. A malformed value is black rather than a crash — a theme is
    /// decoration, and nothing here is worth bringing the app down for.
    public init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0
        red = Double((value >> 16) & 0xff) / 255
        green = Double((value >> 8) & 0xff) / 255
        blue = Double(value & 0xff) / 255
    }
}

/// A background theme, carrying the whole palette rather than just a colour, so
/// a light background still reads: the app never assumes a dark canvas.
///
/// These are the same six the web app offers, so the two look like one product.
public struct Background: Identifiable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let isDark: Bool
    public let background: RGB
    public let surface: RGB
    public let border: RGB
    public let text: RGB
    public let muted: RGB

    public var id: String { key }

    public static let all: [Background] = [
        Background(
            key: "midnight", label: "Midnight", isDark: true,
            background: RGB(hex: "#12141a"), surface: RGB(hex: "#1a1d26"),
            border: RGB(hex: "#272b38"), text: RGB(hex: "#e8eaf0"), muted: RGB(hex: "#8b90a3")
        ),
        Background(
            key: "ink", label: "Ink", isDark: true,
            background: RGB(hex: "#07080b"), surface: RGB(hex: "#111318"),
            border: RGB(hex: "#1f2229"), text: RGB(hex: "#e6e8ee"), muted: RGB(hex: "#808493")
        ),
        Background(
            key: "slate", label: "Slate", isDark: true,
            background: RGB(hex: "#1b2029"), surface: RGB(hex: "#242a35"),
            border: RGB(hex: "#333b49"), text: RGB(hex: "#e9edf4"), muted: RGB(hex: "#929aac")
        ),
        Background(
            key: "forest", label: "Forest", isDark: true,
            background: RGB(hex: "#0f1a15"), surface: RGB(hex: "#17241e"),
            border: RGB(hex: "#24352c"), text: RGB(hex: "#e6f0e9"), muted: RGB(hex: "#879a90")
        ),
        Background(
            key: "paper", label: "Paper", isDark: false,
            background: RGB(hex: "#f2f3f7"), surface: RGB(hex: "#ffffff"),
            border: RGB(hex: "#dcdfe8"), text: RGB(hex: "#1d2028"), muted: RGB(hex: "#666c7d")
        ),
        Background(
            key: "parchment", label: "Parchment", isDark: false,
            background: RGB(hex: "#f5f0e4"), surface: RGB(hex: "#fffcf3"),
            border: RGB(hex: "#e3dac5"), text: RGB(hex: "#2b2618"), muted: RGB(hex: "#6f6853")
        )
    ]

    public static func named(_ key: String) -> Background {
        all.first { $0.key == key } ?? all[0]
    }
}

/// Which background the app is wearing. One line of state, kept out of the views
/// so the setting survives a relaunch.
public final class BackgroundStore: ObservableObject {
    private static let key = "background"

    @Published public var selected: String {
        didSet { UserDefaults.standard.set(selected, forKey: Self.key) }
    }

    public var current: Background { Background.named(selected) }

    public init() {
        selected = UserDefaults.standard.string(forKey: Self.key) ?? Background.all[0].key
    }
}
