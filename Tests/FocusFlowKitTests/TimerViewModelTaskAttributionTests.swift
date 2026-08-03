import Foundation
import Testing
@testable import FocusFlowKit

@MainActor final class ActiveTaskSpy: ActiveTaskProviding {
    var activeTaskID: UUID?
    private(set) var credited: [UUID] = []
    func creditFocusSession(to id: UUID) { credited.append(id) }
}

@MainActor
@Suite struct TimerViewModelTaskAttributionTests {
    private func makeVM(
        tasks: ActiveTaskProviding?,
        recorder: SessionRecorderSpy,
        ticker: FakeTicker,
        clock: FakeClock
    ) -> TimerViewModel {
        TimerViewModel(
            settings: PomodoroSettings(focusDuration: 60, shortBreakDuration: 30,
                                       longBreakDuration: 60, longBreakInterval: 4),
            ticker: ticker, clock: clock,
            notifications: NotificationSpy(), sound: SoundSpy(),
            sessionRecorder: recorder, tasks: tasks)
    }

    @Test func stampsAndCreditsTheActiveTask() {
        let spy = ActiveTaskSpy()
        let id = UUID()
        spy.activeTaskID = id
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: spy, recorder: recorder, ticker: ticker, clock: clock)

        vm.start()
        clock.advance(by: 61)
        vm.tick()

        #expect(recorder.recorded.count == 1)
        #expect(recorder.recorded.first?.taskID == id)
        #expect(spy.credited == [id])
    }

    @Test func recordsNilTaskIdAndCreditsNothingWhenNoActiveTask() {
        let spy = ActiveTaskSpy()          // activeTaskID stays nil
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: spy, recorder: recorder, ticker: ticker, clock: clock)

        vm.start()
        clock.advance(by: 61)
        vm.tick()

        #expect(recorder.recorded.first?.taskID == nil)
        #expect(spy.credited.isEmpty)
    }

    @Test func worksWithNoTaskProviderAtAll() {
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: nil, recorder: recorder, ticker: ticker, clock: clock)

        vm.start()
        clock.advance(by: 61)
        vm.tick()

        #expect(recorder.recorded.count == 1)
        #expect(recorder.recorded.first?.taskID == nil)
    }

    /// A completed break must not be credited to anything.
    @Test func creditsNothingWhenABreakCompletes() {
        let spy = ActiveTaskSpy()
        spy.activeTaskID = UUID()
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: spy, recorder: recorder, ticker: ticker, clock: clock)

        vm.skip()                 // focus -> short break, no credit for a skip
        vm.start()
        clock.advance(by: 31)
        vm.tick()

        #expect(vm.phase == .focus)
        #expect(recorder.recorded.isEmpty)
        #expect(spy.credited.isEmpty)
    }
}
