import Foundation

/// One theme's share of a period.
public struct ThemeSlice: Identifiable, Equatable {
    public let theme: String
    public let seconds: Int
    /// Which colour the theme wears, the same one wherever it appears.
    public let colour: Int

    public var id: String { theme }
}

/// One bar of the chart, with everything drawing it needs already worked out.
///
/// The labels are formatted here rather than in the view because building a date
/// formatter is expensive, and the chart would otherwise build two per bar on
/// every redraw — which is what made pointing at it feel slow.
public struct PeriodBreakdown: Identifiable, Equatable {
    public let start: Date
    public let title: String
    public let shortTitle: String
    public let seconds: Int
    public let slices: [ThemeSlice]

    public var id: Date { start }
}

/// The colours themes are drawn in. Assignment follows the order a theme first
/// appears in the log, so a theme keeps its colour as the log grows and two
/// people looking at the same file see the same chart.
public enum ChartPalette {
    public static let colours: [RGB] = [
        RGB(hex: "#f2766b"), RGB(hex: "#4aa3df"), RGB(hex: "#63c39b"),
        RGB(hex: "#e2b04a"), RGB(hex: "#a98bdc"), RGB(hex: "#ef8fb4"),
        RGB(hex: "#5bc0c7"), RGB(hex: "#c4a484"), RGB(hex: "#8fbf5e"),
        RGB(hex: "#e08a4c"), RGB(hex: "#7f8fd6"), RGB(hex: "#cf6f9b")
    ]

    public static func colour(_ index: Int) -> RGB {
        colours[((index % colours.count) + colours.count) % colours.count]
    }

    /// The themes in the order they first show up, which is the order they are
    /// given colours in.
    public static func order(of sessions: [Session]) -> [String] {
        var seen: Set<String> = []
        var order: [String] = []
        for session in sessions {
            let theme = Statistics.label(for: session.theme)
            if seen.insert(theme).inserted { order.append(theme) }
        }
        return order
    }
}
