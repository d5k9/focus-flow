import UserNotifications
import FocusFlowKit

/// Posts desktop alerts via UNUserNotificationCenter. Honours the user's
/// "Desktop Alerts" preference and degrades silently (never crashes) when
/// authorization is denied — per the spec error-handling rules.
final class UserNotificationService: NotificationScheduling {
    private let isEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func notifyPhaseComplete(finished: PomodoroPhase, next: PomodoroPhase) {
        guard isEnabled() else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(finished.title) complete"
        content.body = "Time for \(next.title)."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)   // failures are ignored, not fatal
    }
}
