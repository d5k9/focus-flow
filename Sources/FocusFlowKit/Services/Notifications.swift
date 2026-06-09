/// Posts desktop alerts on phase completion. The concrete implementation
/// wraps UNUserNotificationCenter in the app target; the view model only
/// sees this protocol so it stays headless and testable.
public protocol NotificationScheduling: AnyObject {
    /// Requests alert+sound authorization. Returns whether it was granted.
    func requestAuthorization() async -> Bool
    /// Posts an alert that `finished` completed and `next` is starting.
    func notifyPhaseComplete(finished: PomodoroPhase, next: PomodoroPhase)
}
