import Foundation
import Observation

/// Owns the engine and ticker, and drives the timer. Anchors to an absolute
/// end-Date and recomputes remaining from the clock each tick, so it never
/// drifts across sleep/wake or timer throttling.
@MainActor
@Observable
public final class TimerViewModel {
    public private(set) var engine: PomodoroEngine
    public private(set) var isRunning = false
    public private(set) var remaining: TimeInterval

    @ObservationIgnored private let ticker: TimerTicker
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let notifications: NotificationScheduling
    @ObservationIgnored private let sound: SoundPlaying
    @ObservationIgnored private var endDate: Date?

    public init(
        settings: PomodoroSettings = .default,
        ticker: TimerTicker,
        clock: Clock = SystemClock(),
        notifications: NotificationScheduling,
        sound: SoundPlaying
    ) {
        let engine = PomodoroEngine(settings: settings)
        self.engine = engine
        self.ticker = ticker
        self.clock = clock
        self.notifications = notifications
        self.sound = sound
        self.remaining = engine.currentPhaseDuration
    }

    // MARK: Derived state for views

    public var phase: PomodoroPhase { engine.currentPhase }
    public var completedFocusCount: Int { engine.completedFocusCount }

    public var displayTime: String {
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    public var progress: Double {
        let total = engine.currentPhaseDuration
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    // MARK: Intents

    public func toggle() { isRunning ? pause() : start() }

    public func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = engine.currentPhaseDuration }
        endDate = clock.now.addingTimeInterval(remaining)
        isRunning = true
        ticker.start { [weak self] in
            Task { @MainActor in self?.tick() }
        }
    }

    public func pause() {
        guard isRunning else { return }
        tick()                 // capture latest remaining before freezing
        ticker.stop()
        endDate = nil
        isRunning = false
    }

    public func reset() {
        stopTimer()
        engine.reset()
        remaining = engine.currentPhaseDuration
    }

    public func skip() {
        stopTimer()
        engine.skip()
        remaining = engine.currentPhaseDuration
    }

    /// Applies new cycle settings. If the timer is idle, the current phase's
    /// remaining time reloads to the new duration; a running session is left
    /// untouched until it next becomes idle.
    public func applySettings(_ settings: PomodoroSettings) {
        engine.settings = settings
        if !isRunning {
            remaining = engine.currentPhaseDuration
        }
    }

    /// Recomputes remaining from the clock. Internal so tests drive it
    /// directly and deterministically (no async hop needed).
    func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(clock.now))
        if remaining <= 0 { completePhase() }
    }

    // MARK: Private

    private func stopTimer() {
        ticker.stop()
        endDate = nil
        isRunning = false
    }

    private func completePhase() {
        stopTimer()
        let finished = engine.currentPhase
        sound.playCompletionChime()
        engine.complete()
        notifications.notifyPhaseComplete(finished: finished, next: engine.currentPhase)
        remaining = engine.currentPhaseDuration
    }
}
