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

/// How wide a bar is and how far apart bars sit.
///
/// A bar is the same width in every tab — five years otherwise turn into five
/// slabs while fourteen days are thin strips — and the width left over is shared
/// between them, so the chart still spans the window.
public enum ChartLayout {
    public static let widestBar: Double = 34
    public static let tightestGap: Double = 6

    public static func barWidth(count: Int, chartWidth: Double) -> Double {
        let count = Double(max(count, 1))
        // Each bar carries its own gap, so a cramped chart still fits.
        let room = chartWidth / count - tightestGap
        return max(2, min(widestBar, room))
    }

    /// The gap belongs to the column rather than sitting between columns, so the
    /// columns tile the chart and pointing anywhere above a gap still picks the
    /// bar next to it.
    public static func gap(count: Int, chartWidth: Double, barWidth: Double) -> Double {
        let count = Double(max(count, 1))
        return max(tightestGap, (chartWidth - barWidth * count) / count)
    }
}

/// Where the hover label sits and how tall it is.
///
/// The label is put above the bar it describes rather than over it, so neither
/// the bar nor the pointer is hidden by the thing explaining them.
public enum ChartLabel {
    /// The gap between the top of the bar and the bottom of the label.
    public static let clearance: Double = 8

    /// Worked out rather than measured, because the position is needed in the
    /// same pass that draws the label.
    public static func height(rows: Int) -> Double {
        let heading = 15.0
        let line = 15.0
        // No rows means one line saying there is nothing to show.
        return 16 + heading + (rows == 0 ? line : Double(rows) * line + line)
    }

    /// How far down from the top of the chart the label starts. It sits on top
    /// of a tall bar only when there is no room above it.
    public static func top(barHeight: Double, chartHeight: Double, footer: Double, labelHeight: Double) -> Double {
        max(0, chartHeight - footer - barHeight - clearance - labelHeight)
    }
}
