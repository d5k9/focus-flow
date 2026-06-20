import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct TimerViewModelTransitionTests {
    @Test func firesCallbackOnPhaseCompletion() {
        let clock = FakeClock(); let ticker = FakeTicker()
        let vm = TimerViewModel(
            settings: PomodoroSettings(focusDuration: 10, shortBreakDuration: 5,
                                       longBreakDuration: 8, longBreakInterval: 4),
            ticker: ticker, clock: clock, notifications: NotificationSpy(), sound: SoundSpy())
        var captured: [(PomodoroPhase, PomodoroPhase)] = []
        vm.onPhaseTransition = { f, n in captured.append((f, n)) }
        vm.start(); clock.advance(by: 10); vm.tick()
        #expect(captured.count == 1)
        #expect(captured.first?.0 == .focus)
        #expect(captured.first?.1 == .shortBreak)
    }
}
