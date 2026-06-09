import Testing
import Foundation
@testable import FocusFlowKit

@MainActor
@Suite struct TimerViewModelTests {
    private func makeVM(
        settings: PomodoroSettings = PomodoroSettings(
            focusDuration: 60, shortBreakDuration: 30,
            longBreakDuration: 45, longBreakInterval: 4),
        clock: FakeClock = FakeClock(),
        ticker: FakeTicker = FakeTicker(),
        sound: SoundSpy = SoundSpy(),
        notifications: NotificationSpy = NotificationSpy()
    ) -> TimerViewModel {
        TimerViewModel(settings: settings, ticker: ticker, clock: clock,
                       notifications: notifications, sound: sound)
    }

    @Test func freshVMShowsFullFocusDuration() {
        let vm = makeVM()
        #expect(vm.phase == .focus)
        #expect(vm.remaining == 60)
        #expect(vm.displayTime == "01:00")
        #expect(vm.isRunning == false)
        #expect(vm.progress == 0)
    }

    @Test func startAnchorsEndDateAndRunsTheTicker() {
        let ticker = FakeTicker()
        let vm = makeVM(ticker: ticker)
        vm.start()
        #expect(vm.isRunning == true)
        #expect(ticker.startCount == 1)
    }

    @Test func tickRecomputesRemainingFromTheClock() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()
        clock.advance(by: 25)
        vm.tick()
        #expect(vm.remaining == 35)
        #expect(vm.displayTime == "00:35")
        #expect(abs(vm.progress - (1 - 35.0/60.0)) < 0.0001)
    }

    @Test func remainingIsImmuneToMissedTicks() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()
        clock.advance(by: 59)
        vm.tick()
        #expect(vm.remaining == 1)
    }

    @Test func reachingZeroCompletesPhaseChimesNotifiesAndAdvances() {
        let clock = FakeClock()
        let ticker = FakeTicker()
        let sound = SoundSpy()
        let notifications = NotificationSpy()
        let vm = makeVM(clock: clock, ticker: ticker, sound: sound, notifications: notifications)
        vm.start()
        clock.advance(by: 60)
        vm.tick()
        #expect(vm.phase == .shortBreak)
        #expect(vm.remaining == 30)
        #expect(vm.isRunning == false)
        #expect(ticker.stopCount >= 1)
        #expect(sound.playCount == 1)
        #expect(notifications.events.count == 1)
        #expect(notifications.events[0].finished == .focus)
        #expect(notifications.events[0].next == .shortBreak)
    }

    @Test func pauseFreezesRemainingAndResumeContinues() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()
        clock.advance(by: 20)
        vm.tick()
        vm.pause()
        #expect(vm.isRunning == false)
        #expect(vm.remaining == 40)
        clock.advance(by: 100)
        #expect(vm.remaining == 40)
        vm.start()
        clock.advance(by: 10)
        vm.tick()
        #expect(vm.remaining == 30)
    }

    @Test func toggleStartsThenPauses() {
        let vm = makeVM()
        vm.toggle()
        #expect(vm.isRunning == true)
        vm.toggle()
        #expect(vm.isRunning == false)
    }

    @Test func resetStopsAndReturnsToFreshFocus() {
        let clock = FakeClock()
        let ticker = FakeTicker()
        let vm = makeVM(clock: clock, ticker: ticker)
        vm.start(); clock.advance(by: 60); vm.tick()  // -> shortBreak
        vm.reset()
        #expect(vm.phase == .focus)
        #expect(vm.remaining == 60)
        #expect(vm.isRunning == false)
        #expect(ticker.stopCount >= 1)
    }

    @Test func skipAdvancesWithoutCreditingAndStops() {
        let vm = makeVM()
        vm.start()
        vm.skip()
        #expect(vm.phase == .shortBreak)
        #expect(vm.remaining == 30)
        #expect(vm.isRunning == false)
        #expect(vm.completedFocusCount == 0)
    }

    @Test func startWhileAlreadyRunningIsNoOp() {
        let ticker = FakeTicker()
        let vm = makeVM(ticker: ticker)
        vm.start()
        vm.start()
        #expect(ticker.startCount == 1)
        #expect(vm.isRunning == true)
    }

    @Test func pauseWhenNotRunningIsNoOp() {
        let ticker = FakeTicker()
        let vm = makeVM(ticker: ticker)
        vm.pause()
        #expect(vm.isRunning == false)
        #expect(ticker.stopCount == 0)
        #expect(vm.remaining == 60)
    }

    @Test func fourthFocusRoutesToLongBreakThroughTheVM() {
        let clock = FakeClock()
        let notifications = NotificationSpy()
        let vm = makeVM(clock: clock, notifications: notifications)

        // Drive a phase to completion through the real VM path (start -> elapse -> tick).
        func completeCurrentPhase() {
            let duration = vm.remaining
            vm.start()
            clock.advance(by: duration)
            vm.tick()
        }

        // Three full focus->short->focus cycles.
        for _ in 0..<3 {
            completeCurrentPhase()   // focus -> shortBreak
            completeCurrentPhase()   // shortBreak -> focus
        }
        #expect(vm.completedFocusCount == 3)
        #expect(vm.phase == .focus)

        completeCurrentPhase()       // 4th focus -> longBreak
        #expect(vm.phase == .longBreak)
        #expect(vm.completedFocusCount == 4)
        #expect(notifications.events.last?.finished == .focus)
        #expect(notifications.events.last?.next == .longBreak)
    }
}
