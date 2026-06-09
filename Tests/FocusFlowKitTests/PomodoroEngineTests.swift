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
