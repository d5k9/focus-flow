import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct PomodoroPhaseTests {
    @Test func breaksAreFlaggedAsBreaks() {
        #expect(PomodoroPhase.focus.isBreak == false)
        #expect(PomodoroPhase.shortBreak.isBreak == true)
        #expect(PomodoroPhase.longBreak.isBreak == true)
    }

    @Test func titlesMatchTheDesign() {
        #expect(PomodoroPhase.focus.title == "Focus Time")
        #expect(PomodoroPhase.shortBreak.title == "Short Break")
        #expect(PomodoroPhase.longBreak.title == "Long Break")
    }
}

@Suite struct PomodoroSettingsTests {
    @Test func defaultsMatchSpec() {
        let s = PomodoroSettings.default
        #expect(s.focusDuration == 25 * 60)
        #expect(s.shortBreakDuration == 5 * 60)
        #expect(s.longBreakDuration == 15 * 60)
        #expect(s.longBreakInterval == 4)
    }

    @Test func durationForPhaseLooksUpTheRightField() {
        let s = PomodoroSettings(
            focusDuration: 100, shortBreakDuration: 200,
            longBreakDuration: 300, longBreakInterval: 4
        )
        #expect(s.duration(for: .focus) == 100)
        #expect(s.duration(for: .shortBreak) == 200)
        #expect(s.duration(for: .longBreak) == 300)
    }

    @Test func longBreakIntervalIsClampedToAtLeastOne() {
        #expect(PomodoroSettings(longBreakInterval: 0).longBreakInterval == 1)
        #expect(PomodoroSettings(longBreakInterval: -5).longBreakInterval == 1)
    }
}
