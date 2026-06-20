import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct BreathingViewModelTests {
    private var box: BreathingPattern { BreathingPattern.all.first { $0.id == "box" }! }

    @Test func tracksPhaseAndCycleAsTimeAdvances() {
        let clock = FakeClock(); let ticker = FakeTicker()
        let vm = BreathingViewModel(pattern: box, targetCycles: 6, clock: clock, ticker: ticker)
        vm.start()
        #expect(vm.phaseLabel == "Inhale")
        #expect(vm.cycleText == "Cycle 1 of 6")
        clock.advance(by: 16); vm.tick()
        #expect(vm.cycleText == "Cycle 2 of 6")
    }

    @Test func finishesAfterAllCycles() {
        let clock = FakeClock(); let ticker = FakeTicker()
        let vm = BreathingViewModel(pattern: box, targetCycles: 1, clock: clock, ticker: ticker)
        vm.start()
        clock.advance(by: 16); vm.tick()
        #expect(vm.isFinished)
    }
}
