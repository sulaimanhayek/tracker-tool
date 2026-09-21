import AppKit
import Combine
import Foundation

/// The countdown. Time left is derived from a wall-clock deadline rather than
/// counted down by the tick, so a missed tick — or a sleeping Mac — cannot make the
/// timer drift away from the clock.
///
/// It is also kept cheap on battery: rather than polling, it wakes exactly when
/// the whole second on screen changes — and when no window of the app can be
/// seen, only once more, at the deadline, to sound the alarm.
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
    private var ticker: Timer?
    private var occlusion: NSObjectProtocol?

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

        // Hidden, minimised or behind other windows, there is no clock to keep
        // up to date; coming back into view catches the display up at once.
        occlusion = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        ticker?.invalidate()
        if let occlusion { NotificationCenter.default.removeObserver(occlusion) }
    }

    /// How long from `remaining` until the whole second shown on screen next
    /// changes — or until the countdown ends, once there is nothing left to show
    /// but zero. The display rounds, so it turns over at each half second.
    public static func delayUntilNextChange(from remaining: TimeInterval) -> TimeInterval {
        let shown = remaining.rounded()
        guard shown > 0 else { return max(0, remaining) }
        return max(0, remaining - (shown - 0.5))
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
        Sounds.tick()
        schedule()
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
        ticker?.invalidate()
        ticker = nil
        if isRunning, let deadline {
            remaining = max(0, deadline.timeIntervalSinceNow)
        }
        isRunning = false
        deadline = nil
    }

    private func tick() {
        guard isRunning, let deadline else { return }
        let left = max(0, deadline.timeIntervalSinceNow)
        guard left > 0 else {
            remaining = 0
            complete()
            return
        }
        // Publishing re-renders every view watching the timer, so it happens
        // only when the second on screen is a different one.
        if left.rounded() != remaining.rounded() || !isOnScreen {
            remaining = left
        }
        schedule()
    }

    private var isOnScreen: Bool {
        NSApp?.occlusionState.contains(.visible) ?? true
    }

    /// One wake-up at a time, for the next moment anything needs doing.
    private func schedule() {
        ticker?.invalidate()
        guard isRunning, let deadline else { return }
        let left = max(0, deadline.timeIntervalSinceNow)
        let delay = isOnScreen ? TimerModel.delayUntilNextChange(from: left) : left
        let timer = Timer(timeInterval: max(0.01, delay), repeats: false) { [weak self] _ in
            self?.tick()
        }
        // Lets macOS fold this wake-up in with others; a tenth of a second late
        // is invisible on a clock that shows whole seconds.
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func complete() {
        stopTicking()
        recordSegment(completed: true)
        Sounds.alarm()

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
