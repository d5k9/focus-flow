import Foundation
@testable import FocusFlowKit

/// A clock whose `now` is fully controlled by the test.
final class FakeClock: Clock {
    var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_000_000)) { current = start }
    var now: Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

/// A ticker that records start/stop and lets the test fire ticks by hand.
final class FakeTicker: TimerTicker {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var isRunning = false
    private var onTick: (() -> Void)?

    func start(onTick: @escaping () -> Void) {
        startCount += 1
        isRunning = true
        self.onTick = onTick
    }
    func stop() {
        stopCount += 1
        isRunning = false
        onTick = nil
    }
    /// Simulate one ticker fire.
    func fire() { onTick?() }
}

/// Records whether a completion chime was requested.
final class SoundSpy: SoundPlaying {
    private(set) var playCount = 0
    func playCompletionChime() { playCount += 1 }
}

/// Records sessions handed to it by the view model.
@MainActor final class SessionRecorderSpy: SessionRecording {
    private(set) var recorded: [FocusSessionRecord] = []
    func record(_ session: FocusSessionRecord) { recorded.append(session) }
}

/// Records sessions and reads them back — stands in for the SwiftData store.
@MainActor final class SessionRecorderAndReaderSpy: SessionRecording, SessionReading {
    private(set) var recorded: [FocusSessionRecord] = []
    var revision = 0
    func record(_ session: FocusSessionRecord) { recorded.append(session); revision += 1 }
    func allSessions() -> [FocusSessionRecord] { recorded }
}

/// Records calls made to the ambient audio engine.
final class AudioEngineSpy: AmbientAudioEngine {
    private(set) var playing: Set<String> = []
    private(set) var volumes: [String: Double] = [:]
    private(set) var stopAllCount = 0
    func play(_ id: String) { playing.insert(id) }
    func stop(_ id: String) { playing.remove(id) }
    func setVolume(_ volume: Double, for id: String) { volumes[id] = volume }
    func stopAll() { stopAllCount += 1; playing.removeAll() }
}

/// Records phase-completion notifications.
final class NotificationSpy: NotificationScheduling {
    private(set) var authorizationRequested = false
    private(set) var events: [(finished: PomodoroPhase, next: PomodoroPhase)] = []
    func requestAuthorization() async -> Bool { authorizationRequested = true; return true }
    func notifyPhaseComplete(finished: PomodoroPhase, next: PomodoroPhase) {
        events.append((finished, next))
    }
}
