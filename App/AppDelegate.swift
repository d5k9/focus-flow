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
    /// Eager because the timer needs it for attribution — cheap, since its
    /// own store stays closed until the list is first read.
    let tasksVM: TasksViewModel
    private let sessionStore: LazySessionStore
    private let notifications: NotificationScheduling
    private let sound: SoundPlaying

    /// Built on first visit to their tab, not at launch. `sessionStore` is
    /// itself lazy, so touching `statsVM` is what finally opens the container.
    lazy var statsVM = StatsViewModel(reader: sessionStore)
    lazy var soundMixerVM = SoundMixerViewModel(
        engine: AVAmbientAudioEngine(),
        ticker: DispatchSourceTimerTicker())

    private var onboardingWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var breakFlow: BreakFlowCoordinator?

    override init() {
        let settings = SettingsStore()
        let notifications: NotificationScheduling =
            UserNotificationService(isEnabled: { settings.desktopAlertsEnabled })
        let sound: SoundPlaying =
            SystemSoundService(isEnabled: { settings.soundEffectsEnabled })
        self.settings = settings
        self.notifications = notifications
        self.sound = sound
        // Constructing this touches no storage — the container is opened on
        // the first recorded session.
        let sessionStore = LazySessionStore {
            try SwiftDataSessionStore(container: AppModelContainer.shared())
        }
        self.sessionStore = sessionStore
        let tasksVM = TasksViewModel(store: {
            try SwiftDataTaskStore(container: AppModelContainer.shared())
        })
        self.tasksVM = tasksVM
        self.timerVM = TimerViewModel(
            settings: settings.pomodoroSettings,
            ticker: DispatchSourceTimerTicker(),
            notifications: notifications,
            sound: sound,
            sessionRecorder: sessionStore,
            tasks: tasksVM
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { _ = await notifications.requestAuthorization() }
        showOnboardingIfNeeded()
        observeSettings()
        breakFlow = BreakFlowCoordinator(timerVM: timerVM)
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
        let window = makeAuxWindow(title: "Welcome to FocusFlow", content: view, size: NSSize(width: 360, height: 360))
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
