import Testing
import Foundation
@testable import FocusFlowKit

@MainActor
@Suite struct SettingsStoreTests {
    /// Each test gets an isolated, empty UserDefaults suite.
    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func unsetKeysReturnDocumentedDefaults() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.focusMinutes == 25)
        #expect(store.shortBreakMinutes == 5)
        #expect(store.longBreakMinutes == 15)
        #expect(store.longBreakInterval == 4)
        #expect(store.soundEffectsEnabled == true)
        #expect(store.desktopAlertsEnabled == true)
        #expect(store.theme == .dark)
        #expect(store.hasCompletedOnboarding == false)
    }

    @Test func valuesRoundTripThroughUserDefaults() {
        let defaults = freshDefaults()
        let writer = SettingsStore(defaults: defaults)
        writer.focusMinutes = 50
        writer.shortBreakMinutes = 8
        writer.longBreakMinutes = 20
        writer.longBreakInterval = 3
        writer.soundEffectsEnabled = false
        writer.desktopAlertsEnabled = false
        writer.theme = .light
        writer.hasCompletedOnboarding = true

        let reader = SettingsStore(defaults: defaults)
        #expect(reader.focusMinutes == 50)
        #expect(reader.shortBreakMinutes == 8)
        #expect(reader.longBreakMinutes == 20)
        #expect(reader.longBreakInterval == 3)
        #expect(reader.soundEffectsEnabled == false)
        #expect(reader.desktopAlertsEnabled == false)
        #expect(reader.theme == .light)
        #expect(reader.hasCompletedOnboarding == true)
    }

    @Test func pomodoroSettingsConvertsMinutesToSeconds() {
        let store = SettingsStore(defaults: freshDefaults())
        store.focusMinutes = 25
        store.shortBreakMinutes = 5
        store.longBreakMinutes = 15
        store.longBreakInterval = 4
        let s = store.pomodoroSettings
        #expect(s.focusDuration == 1500)
        #expect(s.shortBreakDuration == 300)
        #expect(s.longBreakDuration == 900)
        #expect(s.longBreakInterval == 4)
    }
}
