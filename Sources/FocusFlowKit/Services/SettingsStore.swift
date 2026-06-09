import Foundation
import Observation

public enum AppTheme: String, CaseIterable, Sendable, Codable {
    case system, light, dark
    public var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light Mode"
        case .dark: return "Dark Mode"
        }
    }
}

/// Observable, typed view over UserDefaults. Property `didSet` writes back
/// immediately; the initializer reads with fallback defaults.
@MainActor
@Observable
public final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    public var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Keys.focusMinutes) } }
    public var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes) } }
    public var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes) } }
    public var longBreakInterval: Int { didSet { defaults.set(longBreakInterval, forKey: Keys.longBreakInterval) } }
    public var soundEffectsEnabled: Bool { didSet { defaults.set(soundEffectsEnabled, forKey: Keys.soundEffects) } }
    public var desktopAlertsEnabled: Bool { didSet { defaults.set(desktopAlertsEnabled, forKey: Keys.desktopAlerts) } }
    public var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: Keys.theme) } }
    public var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.focusMinutes = (defaults.object(forKey: Keys.focusMinutes) as? Int) ?? 25
        self.shortBreakMinutes = (defaults.object(forKey: Keys.shortBreakMinutes) as? Int) ?? 5
        self.longBreakMinutes = (defaults.object(forKey: Keys.longBreakMinutes) as? Int) ?? 15
        self.longBreakInterval = (defaults.object(forKey: Keys.longBreakInterval) as? Int) ?? 4
        self.soundEffectsEnabled = (defaults.object(forKey: Keys.soundEffects) as? Bool) ?? true
        self.desktopAlertsEnabled = (defaults.object(forKey: Keys.desktopAlerts) as? Bool) ?? true
        self.theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .dark
        self.hasCompletedOnboarding = (defaults.object(forKey: Keys.onboarding) as? Bool) ?? false
    }

    /// Engine-ready settings derived from the stored minute values.
    public var pomodoroSettings: PomodoroSettings {
        PomodoroSettings(
            focusDuration: TimeInterval(focusMinutes) * 60,
            shortBreakDuration: TimeInterval(shortBreakMinutes) * 60,
            longBreakDuration: TimeInterval(longBreakMinutes) * 60,
            longBreakInterval: longBreakInterval
        )
    }

    private enum Keys {
        static let focusMinutes = "settings.focusMinutes"
        static let shortBreakMinutes = "settings.shortBreakMinutes"
        static let longBreakMinutes = "settings.longBreakMinutes"
        static let longBreakInterval = "settings.longBreakInterval"
        static let soundEffects = "settings.soundEffectsEnabled"
        static let desktopAlerts = "settings.desktopAlertsEnabled"
        static let theme = "settings.theme"
        static let onboarding = "settings.hasCompletedOnboarding"
    }
}
