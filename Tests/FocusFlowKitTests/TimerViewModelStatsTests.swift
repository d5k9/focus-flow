import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct TimerViewModelStatsTests {
    private func makeVM(_ recorder: SessionRecorderSpy, clock: FakeClock, ticker: FakeTicker)
        -> TimerViewModel {
        TimerViewModel(
            settings: PomodoroSettings(focusDuration: 60, shortBreakDuration: 30,
                                       longBreakDuration: 45, longBreakInterval: 4),
            ticker: ticker, clock: clock,
            notifications: NotificationSpy(), sound: SoundSpy(),
            sessionRecorder: recorder)
    }

    @Test func recordsOneFocusSessionWhenFocusCompletes() {
        let recorder = SessionRecorderSpy(); let clock = FakeClock(); let ticker = FakeTicker()
        let vm = makeVM(recorder, clock: clock, ticker: ticker)
        vm.start()
        clock.advance(by: 60); vm.tick()      // focus elapses
        #expect(recorder.recorded.count == 1)
        #expect(recorder.recorded.first?.duration == 60)
    }

    @Test func doesNotRecordWhenBreakCompletes() {
        let recorder = SessionRecorderSpy(); let clock = FakeClock(); let ticker = FakeTicker()
        let vm = makeVM(recorder, clock: clock, ticker: ticker)
        vm.start(); clock.advance(by: 60); vm.tick()   // focus -> short break
        vm.start(); clock.advance(by: 30); vm.tick()   // break elapses
        #expect(recorder.recorded.count == 1)          // still just the focus session
    }
}
