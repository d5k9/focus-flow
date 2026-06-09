import FocusFlowKit

/// Placeholders so the shell builds and runs before Task 15 wires the
/// real UserNotifications / AppKit services. Replaced, not extended.
final class NoopNotificationService: NotificationScheduling {
    func requestAuthorization() async -> Bool { true }
    func notifyPhaseComplete(finished: PomodoroPhase, next: PomodoroPhase) {}
}

final class NoopSoundService: SoundPlaying {
    func playCompletionChime() {}
}
