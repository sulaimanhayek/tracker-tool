import Combine
import Foundation

/// The countdown. Time left is derived from a wall-clock deadline rather than
/// counted down by the tick, so a missed tick — or a sleeping Mac — cannot make the
/// timer drift away from the clock.
public final class TimerModel: ObservableObject {
    @Published public private(set) var mode: TimerMode = .focus
    @Published public private(set) var remaining: TimeInterval
    @Published public private(set) var isRunning = false
    @Published public private(set) var completedRounds = 0

    @Published public var durations: [TimerMode: Int] {
        didSet { saveDurations() }
    }

    /// When the current stretch of focus began, for the session log.
    private var segmentStart: Date?
    private var deadline: Date?
    private var ticker: AnyCancellable?

    private let log: SessionLog
    private let themes: ThemeStore

    public var total: TimeInterval { TimeInterval((durations[mode] ?? mode.defaultMinutes) * 60) }
    public var progress: Double { total > 0 ? remaining / total : 0 }

    public init(log: SessionLog, themes: ThemeStore) {
        self.log = log
        self.themes = themes

        var loaded: [TimerMode: Int] = [:]
        for mode in TimerMode.allCases {
            let stored = UserDefaults.standard.integer(forKey: "duration.\(mode.rawValue)")
            loaded[mode] = stored > 0 ? stored : mode.defaultMinutes
        }
        durations = loaded
        remaining = TimeInterval((loaded[.focus] ?? 60) * 60)
        completedRounds = TimerModel.roundsSoFarToday()
    }

    /// The round count is a today figure, so it starts again on a new day.
    private static func roundsSoFarToday() -> Int {
        let stored = UserDefaults.standard.string(forKey: "roundsDate")
        guard stored == today() else { return 0 }
        return UserDefaults.standard.integer(forKey: "completedRoundsToday")
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - Controls

    public func toggle() { isRunning ? pause() : start() }

    public func start() {
        guard !isRunning else { return }
        deadline = Date().addingTimeInterval(remaining)
        if segmentStart == nil { segmentStart = Date() }
        isRunning = true

        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    public func pause() {
        guard isRunning else { return }
        stopTicking()
        // Pausing banks the focus time already earned, so a long pause is not
        // silently counted as work when the session is later finished.
        recordSegment(completed: false)
    }

    public func reset() {
        stopTicking()
        recordSegment(completed: false)
        remaining = total
    }

    public func select(_ mode: TimerMode) {
        guard mode != self.mode else { return }
        stopTicking()
        recordSegment(completed: false)
        self.mode = mode
        remaining = total
    }

    public func applyDurationChange() {
        guard !isRunning else { return }
        remaining = total
    }

    // MARK: - Internals

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
        if isRunning, let deadline {
            remaining = max(0, deadline.timeIntervalSinceNow)
        }
        isRunning = false
        deadline = nil
    }

    private func tick() {
        guard let deadline else { return }
        remaining = max(0, deadline.timeIntervalSinceNow)
        if remaining <= 0 { complete() }
    }

    private func complete() {
        stopTicking()
        recordSegment(completed: true)
        Chime.play()

        if mode == .focus {
            completedRounds = TimerModel.roundsSoFarToday() + 1
            UserDefaults.standard.set(completedRounds, forKey: "completedRoundsToday")
            UserDefaults.standard.set(TimerModel.today(), forKey: "roundsDate")
            mode = completedRounds % roundsBeforeLongBreak == 0 ? .longBreak : .shortBreak
        } else {
            mode = .focus
        }

        remaining = total
    }

    /// Writes the focus time earned since the timer was last started. Breaks are not
    /// logged, and neither is a stretch too short to be meaningful.
    private func recordSegment(completed: Bool) {
        defer { segmentStart = nil }
        guard mode.isTracked, let start = segmentStart else { return }
        let end = Date()
        guard end.timeIntervalSince(start) >= 60 else { return }
        log.append(Session(start: start, end: end, theme: themes.selected ?? "", completed: completed))
    }

    private func saveDurations() {
        for (mode, minutes) in durations {
            UserDefaults.standard.set(minutes, forKey: "duration.\(mode.rawValue)")
        }
    }
}
