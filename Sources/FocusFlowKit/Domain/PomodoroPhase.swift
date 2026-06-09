/// The three phases of a Pomodoro cycle. Pure value type — no clock, no UI.
public enum PomodoroPhase: String, Sendable, CaseIterable, Codable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool {
        switch self {
        case .focus: return false
        case .shortBreak, .longBreak: return true
        }
    }

    /// Display title used in the session list and completion notifications.
    public var title: String {
        switch self {
        case .focus: return "Focus Time"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}
