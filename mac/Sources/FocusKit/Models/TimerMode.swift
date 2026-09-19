import Foundation

public enum TimerMode: String, CaseIterable, Codable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    public var defaultMinutes: Int {
        switch self {
        case .focus: return 60
        case .shortBreak: return 5
        case .longBreak: return 15
        }
    }

    /// Only focus time is tracked; breaks are not work.
    public var isTracked: Bool { self == .focus }
}

/// Focus rounds completed before a long break is suggested.
let roundsBeforeLongBreak = 4
