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

@Suite struct PomodoroEngineTests {
    @Test func startsInFocusWithZeroCount() {
        let e = PomodoroEngine()
        #expect(e.currentPhase == .focus)
        #expect(e.completedFocusCount == 0)
    }

    @Test func completingFocusCreditsAndGoesToShortBreak() {
        var e = PomodoroEngine()
        e.complete()
        #expect(e.completedFocusCount == 1)
        #expect(e.currentPhase == .shortBreak)
    }

    @Test func completingABreakGoesBackToFocusWithoutCrediting() {
        var e = PomodoroEngine()
        e.complete()                 // focus #1 done -> shortBreak
        e.complete()                 // shortBreak done -> focus
        #expect(e.currentPhase == .focus)
        #expect(e.completedFocusCount == 1)
    }

    @Test func everyFourthFocusLeadsToALongBreak() {
        var e = PomodoroEngine(settings: PomodoroSettings(longBreakInterval: 4))
        for _ in 0..<3 {
            e.complete()             // focus -> shortBreak
            e.complete()             // shortBreak -> focus
        }
        #expect(e.completedFocusCount == 3)
        e.complete()                 // 4th focus completed
        #expect(e.completedFocusCount == 4)
        #expect(e.currentPhase == .longBreak)
    }

    @Test func skippingFocusDoesNotCreditAndGoesToShortBreak() {
        var e = PomodoroEngine(settings: PomodoroSettings(longBreakInterval: 1))
        e.skip()
        #expect(e.completedFocusCount == 0)
        #expect(e.currentPhase == .shortBreak)
    }

    @Test func skippingABreakGoesToFocus() {
        var e = PomodoroEngine()
        e.complete()                 // -> shortBreak
        e.skip()                     // skip break -> focus
        #expect(e.currentPhase == .focus)
        #expect(e.completedFocusCount == 1)
    }

    @Test func resetReturnsToFreshFocus() {
        var e = PomodoroEngine()
        e.complete(); e.complete(); e.complete()
        e.reset()
        #expect(e.currentPhase == .focus)
        #expect(e.completedFocusCount == 0)
    }

    @Test func currentPhaseDurationFollowsSettings() {
        var e = PomodoroEngine(settings: PomodoroSettings(
            focusDuration: 1500, shortBreakDuration: 300,
            longBreakDuration: 900, longBreakInterval: 4))
        #expect(e.currentPhaseDuration == 1500)
        e.complete()
        #expect(e.currentPhaseDuration == 300)
    }

    @Test func completingALongBreakGoesBackToFocus() {
        var e = PomodoroEngine(settings: PomodoroSettings(longBreakInterval: 1))
        e.complete()                 // focus #1 -> longBreak (interval 1)
        #expect(e.currentPhase == .longBreak)
        e.complete()                 // longBreak -> focus
        #expect(e.currentPhase == .focus)
        #expect(e.completedFocusCount == 1)
    }

    @Test func countIsNotResetAfterALongBreakSoNextFocusIsShort() {
        var e = PomodoroEngine(settings: PomodoroSettings(longBreakInterval: 4))
        // Drive through three full cycles, then the 4th focus -> long break.
        for _ in 0..<3 { e.complete(); e.complete() }
        e.complete()                 // 4th focus -> longBreak, count 4
        #expect(e.currentPhase == .longBreak)
        e.complete()                 // longBreak -> focus, count stays 4
        #expect(e.completedFocusCount == 4)
        e.complete()                 // 5th focus completed, count 5, 5 % 4 != 0
        #expect(e.completedFocusCount == 5)
        #expect(e.currentPhase == .shortBreak)   // NOT another long break
    }
}
