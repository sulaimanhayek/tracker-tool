import Foundation

public enum Grain: String, CaseIterable, Identifiable {
    case day, week, month, year

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .day: return "Daily"
        case .week: return "Weekly"
        case .month: return "Monthly"
        case .year: return "Yearly"
        }
    }

    public var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// How many periods the chart looks back over.
    public var span: Int {
        switch self {
        case .day: return 14
        case .week: return 12
        case .month: return 12
        case .year: return 5
        }
    }

    /// Formatters are kept rather than made on demand: building one costs more
    /// than formatting with it, and the chart formats a label per bar.
    private static let cache = FormatterCache()

    public func title(for date: Date, calendar: Calendar) -> String {
        let formatter = Grain.cache.formatter(for: "\(rawValue).title", calendar: calendar)
        switch self {
        case .day: formatter.dateFormat = "EEE d MMM"
        case .week: formatter.dateFormat = "'w/c' d MMM"
        case .month: formatter.dateFormat = "MMMM yyyy"
        case .year: formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }

    public func shortTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = Grain.cache.formatter(for: "\(rawValue).short", calendar: calendar)
        switch self {
        case .day: formatter.dateFormat = "EEEEE"
        case .week: formatter.dateFormat = "d MMM"
        case .month: formatter.dateFormat = "MMM"
        case .year: formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}

/// One date formatter per format string, made once and reused.
final class FormatterCache: @unchecked Sendable {
    private var formatters: [String: DateFormatter] = [:]
    private let lock = NSLock()

    func formatter(for key: String, calendar: Calendar) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = formatters[key] { return existing }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatters[key] = formatter
        return formatter
    }
}
