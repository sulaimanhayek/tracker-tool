import Foundation

/// One row of sessions.csv. A session is recorded when focus time ends, whether it
/// ran to completion or was stopped early — an interrupted hour is still an hour.
public struct Session: Identifiable, Equatable {
    public let id: UUID
    public let start: Date
    public let end: Date
    public let theme: String
    public let completed: Bool

    public var seconds: Int { max(0, Int(end.timeIntervalSince(start))) }
    public var minutes: Double { Double(seconds) / 60 }

    public init(id: UUID = UUID(), start: Date, end: Date, theme: String, completed: Bool) {
        self.id = id
        self.start = start
        self.end = end
        self.theme = theme
        self.completed = completed
    }
}
