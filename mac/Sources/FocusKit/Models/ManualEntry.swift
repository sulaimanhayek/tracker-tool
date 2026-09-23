import Foundation

/// Focus time that happened away from the timer, entered by hand.
///
/// A manual row is an ordinary session — same six columns, same file — because the
/// point of the log is what the day held, not which button recorded it.
public enum ManualEntry {
    /// The longest stretch that can be entered in one go. Anything longer is far
    /// more likely to be a mistyped time than a day spent at the desk.
    public static let longestSeconds = 12 * 60 * 60

    /// Builds the session from the day picked and two clock times. A finish that
    /// falls before the start is read as having crossed midnight, which is how the
    /// log itself reads such a row back.
    public static func session(
        day: Date,
        from startTime: Date,
        to endTime: Date,
        theme: String,
        calendar: Calendar = .current
    ) -> Session {
        let start = combine(day: day, time: startTime, calendar: calendar)
        var end = combine(day: day, time: endTime, calendar: calendar)
        if end <= start { end = end.addingTimeInterval(24 * 60 * 60) }
        return Session(start: start, end: end, theme: theme, completed: true)
    }

    private static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        parts.hour = clock.hour
        parts.minute = clock.minute
        parts.second = 0
        return calendar.date(from: parts) ?? day
    }

    /// What is wrong with the entry, in words the sheet can show, or nil if it can
    /// be saved. Time yet to happen is refused: the log is a record, not a plan.
    public static func problem(with session: Session, now: Date = Date()) -> String? {
        if session.seconds < 60 {
            return "That is less than a minute."
        }
        if session.seconds > longestSeconds {
            return "That is longer than \(longestSeconds / 3600) hours — check the times."
        }
        if session.end > now.addingTimeInterval(60) {
            return "That time has not happened yet."
        }
        return nil
    }

    /// Whether two stretches of time cover any of the same minutes. Overlapping
    /// entries are allowed — they are only worth mentioning, since double-counting
    /// an hour is usually a slip rather than a decision.
    public static func overlap(_ session: Session, _ other: Session) -> Bool {
        session.start < other.end && other.start < session.end
    }
}
