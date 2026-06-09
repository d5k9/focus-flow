import AppKit
import SwiftUI
import FocusFlowKit
import Observation

/// Owns the shared object graph and the auxiliary (non-popover) windows.
/// Onboarding and Preferences use AppKit windows hosting SwiftUI — the same
/// borderless-window pattern the future Relaxation Mode will reuse.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore
    let timerVM: TimerViewModel
    private let notifications: NotificationScheduling
    private let sound: SoundPlaying

    private var onboardingWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    override init() {
        let settings = SettingsStore()
        // Task 15 swaps these no-ops for the real macOS services.
        let notifications: NotificationScheduling = NoopNotificationService()
        let sound: SoundPlaying = NoopSoundService()
        self.settings = settings
        self.notifications = notifications
        self.sound = sound
        self.timerVM = TimerViewModel(
            settings: settings.pomodoroSettings,
            ticker: DispatchSourceTimerTicker(),
            notifications: notifications,
            sound: sound
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { _ = await notifications.requestAuthorization() }
        showOnboardingIfNeeded()
        observeSettings()
    }

    /// Re-pushes pomodoro settings into the VM whenever a tracked settings
    /// property changes. Observation fires the closure once per change; we
    /// re-register each time to keep tracking.
    private func observeSettings() {
        withObservationTracking {
            _ = settings.focusMinutes
            _ = settings.shortBreakMinutes
            _ = settings.longBreakMinutes
            _ = settings.longBreakInterval
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.timerVM.applySettings(self.settings.pomodoroSettings)
                self.observeSettings()   // re-arm
            }
        }
    }

    func showOnboardingIfNeeded() {
        guard !settings.hasCompletedOnboarding else { return }
        showOnboarding()
    }

    func showOnboarding() {
        if let w = onboardingWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let view = OnboardingView { [weak self] in
            self?.settings.hasCompletedOnboarding = true
            self?.onboardingWindow?.close()
        }
        let window = makeAuxWindow(title: "Welcome to FocusFlow", content: view, size: NSSize(width: 360, height: 320))
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPreferences() {
        if let w = preferencesWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let view = PreferencesView(settings: settings)
        let window = makeAuxWindow(title: "FocusFlow Preferences", content: view, size: NSSize(width: 320, height: 460))
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeAuxWindow<V: View>(title: String, content: V, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: content)
        return window
    }
}
