import Foundation

/// Cycle configuration: phase durations and how often a long break occurs.
public struct PomodoroSettings: Equatable, Sendable, Codable {
    public var focusDuration: TimeInterval
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    /// A long break replaces the short break after every `longBreakInterval`
    /// completed focus sessions. The initializer clamps this to >= 1; values
    /// below 1 set via direct mutation are unsupported (the UI uses a 1...N stepper).
    public var longBreakInterval: Int

    public init(
        focusDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        longBreakInterval: Int = 4
    ) {
        self.focusDuration = focusDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.longBreakInterval = max(1, longBreakInterval)
    }

    public func duration(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: return focusDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    public static let `default` = PomodoroSettings()
}
