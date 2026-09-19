import Foundation

/// The session log: append-only, one row per finished focus session.
///
/// Nothing here ever rewrites an existing row. Totals by day, week, month and year
/// are computed from this file rather than stored alongside it, so the numbers can
/// never drift from the record and a crash can cost at most the row being written.
public final class SessionLog: ObservableObject {
    public static let header = "date,start,end,minutes,theme,completed"

    @Published public private(set) var sessions: [Session] = []
    @Published public private(set) var lastError: String?

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public init() {
        load()
    }

    // MARK: - Reading

    public func load() {
        guard let text = try? String(contentsOf: DataFolder.sessionsFile, encoding: .utf8) else {
            sessions = []
            return
        }

        sessions = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .dropFirst() // header
            .compactMap { parse(row: String($0)) }
    }

    private func parse(row: String) -> Session? {
        let fields = CSV.parse(row: row)
        guard fields.count >= 6 else { return nil }
        guard let start = date(day: fields[0], time: fields[1]) else { return nil }

        // The end time can fall past midnight; a session is dated by when it began.
        var end = date(day: fields[0], time: fields[2]) ?? start
        if end < start { end = end.addingTimeInterval(24 * 60 * 60) }

        return Session(start: start, end: end, theme: fields[4], completed: fields[5] == "yes")
    }

    private func date(day: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: "\(day) \(time)")
    }

    // MARK: - Writing

    /// Appends one row. The file is opened, extended and closed on each call, so an
    /// external edit between sessions is picked up rather than overwritten.
    public func append(_ session: Session) {
        guard session.seconds > 0 else { return }

        let row = CSV.row([
            dayFormatter.string(from: session.start),
            timeFormatter.string(from: session.start),
            timeFormatter.string(from: session.end),
            String(format: "%.2f", session.minutes),
            session.theme,
            session.completed ? "yes" : "no"
        ])

        do {
            DataFolder.ensureExists()
            let file = DataFolder.sessionsFile

            if !FileManager.default.fileExists(atPath: file.path) {
                try (SessionLog.header + "\n").write(to: file, atomically: true, encoding: .utf8)
            }

            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = (row + "\n").data(using: .utf8) {
                try handle.write(contentsOf: data)
            }

            sessions.append(session)
            lastError = nil
        } catch {
            // Losing a row must never take the timer down with it.
            lastError = "Could not write to sessions.csv: \(error.localizedDescription)"
        }
    }
}
