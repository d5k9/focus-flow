import Foundation

/// Pure, clock-driven guided-breathing state machine. Like PomodoroEngine it
/// holds no clock — the caller passes total `elapsed` seconds.
public struct BreathingSession: Equatable, Sendable {
    public let pattern: BreathingPattern
    public let targetCycles: Int
    public private(set) var completedCycles: Int = 0
    private var stepIndex: Int = 0

    public init(pattern: BreathingPattern, targetCycles: Int) {
        self.pattern = pattern; self.targetCycles = targetCycles
    }

    public var currentKind: BreathPhaseKind { pattern.steps[stepIndex].kind }
    public var isFinished: Bool { completedCycles >= targetCycles }

    /// Seconds left in the current step, given total elapsed seconds.
    public func remaining(elapsed: TimeInterval) -> TimeInterval {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return 0 }
        var within = elapsed.truncatingRemainder(dividingBy: cycle)
        for step in pattern.steps {
            if within < step.duration { return step.duration - within }
            within -= step.duration
        }
        return 0
    }

    /// Recomputes cycle count and current step from total elapsed seconds.
    public mutating func update(elapsed: TimeInterval) {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return }
        completedCycles = min(targetCycles, Int(elapsed / cycle))
        var within = elapsed.truncatingRemainder(dividingBy: cycle)
        var idx = 0
        for (i, step) in pattern.steps.enumerated() {
            if within < step.duration { idx = i; break }
            within -= step.duration
            idx = i
        }
        stepIndex = isFinished ? 0 : idx
    }
}
