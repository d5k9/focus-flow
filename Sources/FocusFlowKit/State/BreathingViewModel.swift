import Foundation
import Observation

@MainActor
@Observable
public final class BreathingViewModel {
    public private(set) var session: BreathingSession
    public private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let ticker: TimerTicker
    @ObservationIgnored private var startDate: Date?

    public init(pattern: BreathingPattern, targetCycles: Int,
                clock: Clock = SystemClock(), ticker: TimerTicker) {
        self.session = BreathingSession(pattern: pattern, targetCycles: targetCycles)
        self.clock = clock; self.ticker = ticker
    }

    public func start() {
        startDate = clock.now
        ticker.start { [weak self] in Task { @MainActor in self?.tick() } }
    }

    public func stop() { ticker.stop(); startDate = nil }

    public var phaseLabel: String { session.currentKind.label }
    public var cycleText: String { "Cycle \(min(session.completedCycles + 1, session.targetCycles)) of \(session.targetCycles)" }
    public var isFinished: Bool { session.isFinished }
    public var stepProgress: Double {
        let stepTotal = stepDuration()
        guard stepTotal > 0 else { return 0 }
        return min(1, max(0, 1 - session.remaining(elapsed: elapsed) / stepTotal))
    }

    /// Recomputes elapsed and session state from the clock. Internal so tests
    /// drive it directly and deterministically (no async hop needed).
    func tick() {
        guard let startDate else { return }
        elapsed = clock.now.timeIntervalSince(startDate)
        session.update(elapsed: elapsed)
        if session.isFinished { stop() }
    }

    private func stepDuration() -> TimeInterval {
        session.pattern.steps.first { $0.kind == session.currentKind }?.duration ?? 0
    }
}
