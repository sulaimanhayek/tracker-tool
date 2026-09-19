import Foundation

public struct Bucket: Identifiable {
    public let id = UUID()
    public let start: Date
    public let seconds: Int

    public var hours: Double { Double(seconds) / 3600 }
}

public struct ThemeTotal: Identifiable {
    public var id: String { theme }
    public let theme: String
    public let seconds: Int
}

/// Every figure the app shows is computed here from the session log. Nothing is
/// cached to disk, so the reports cannot fall out of step with the record.
public enum Statistics {
    public static func start(of date: Date, grain: Grain, calendar: Calendar) -> Date {
        switch grain {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start ?? date
        }
    }

    /// One bucket per period, oldest first, including periods with no sessions so
    /// the gaps in a run of days are visible rather than closed up.
    public static func buckets(
        _ sessions: [Session],
        grain: Grain,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Bucket] {
        let current = start(of: now, grain: grain, calendar: calendar)
        let starts: [Date] = (0..<grain.span).reversed().compactMap {
            calendar.date(byAdding: grain.component, value: -$0, to: current)
        }

        var totals: [Date: Int] = [:]
        for session in sessions {
            let bucket = start(of: session.start, grain: grain, calendar: calendar)
            totals[bucket, default: 0] += session.seconds
        }

        return starts.map { Bucket(start: $0, seconds: totals[$0] ?? 0) }
    }

    public static func total(
        _ sessions: [Session],
        grain: Grain,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let current = start(of: now, grain: grain, calendar: calendar)
        return sessions
            .filter { start(of: $0.start, grain: grain, calendar: calendar) == current }
            .reduce(0) { $0 + $1.seconds }
    }

    public static func byTheme(
        _ sessions: [Session],
        grain: Grain,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ThemeTotal] {
        let current = start(of: now, grain: grain, calendar: calendar)
        var totals: [String: Int] = [:]

        for session in sessions
        where start(of: session.start, grain: grain, calendar: calendar) == current {
            let theme = session.theme.isEmpty ? "No theme" : session.theme
            totals[theme, default: 0] += session.seconds
        }

        return totals
            .map { ThemeTotal(theme: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }

    public static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
