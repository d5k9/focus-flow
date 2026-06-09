import Foundation

/// Pure value-type Pomodoro state machine. Owns the current phase and the
/// completed-focus count, and computes the next phase. It is *driven* — it
/// has no clock and no notion of elapsed time. See the transition contract
/// in the plan / tests for exact semantics.
public struct PomodoroEngine: Equatable, Sendable {
    public private(set) var currentPhase: PomodoroPhase
    public private(set) var completedFocusCount: Int
    public var settings: PomodoroSettings

    public init(settings: PomodoroSettings = .default) {
        self.settings = settings
        self.currentPhase = .focus
        self.completedFocusCount = 0
    }

    /// Duration of the phase currently in progress, per the settings.
    public var currentPhaseDuration: TimeInterval {
        settings.duration(for: currentPhase)
    }

    /// Marks the current phase finished and advances. A completed focus phase
    /// is credited toward the long-break interval.
    public mutating func complete() { advance(creditFocus: true) }

    /// Skips the current phase. A skipped focus is never credited, so it
    /// always leads to a short break.
    public mutating func skip() { advance(creditFocus: false) }

    /// Returns to a fresh first focus phase and clears the counter.
    public mutating func reset() {
        currentPhase = .focus
        completedFocusCount = 0
    }

    private mutating func advance(creditFocus: Bool) {
        if currentPhase == .focus {
            if creditFocus { completedFocusCount += 1 }
            let dueLongBreak = creditFocus
                && completedFocusCount % settings.longBreakInterval == 0
            currentPhase = dueLongBreak ? .longBreak : .shortBreak
        } else {
            currentPhase = .focus
        }
    }
}
