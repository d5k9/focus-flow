import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct SoundMixerViewModelTests {
    private func makeVM() -> (SoundMixerViewModel, AudioEngineSpy, FakeClock, FakeTicker) {
        let e = AudioEngineSpy(); let c = FakeClock(); let t = FakeTicker()
        return (SoundMixerViewModel(engine: e, clock: c, ticker: t), e, c, t)
    }

    @Test func togglingPlaysAndStops() {
        let (vm, engine, _, _) = makeVM()
        vm.toggle("rain")
        #expect(vm.isOn("rain")); #expect(engine.playing.contains("rain"))
        vm.toggle("rain")
        #expect(!vm.isOn("rain")); #expect(!engine.playing.contains("rain"))
    }

    @Test func settingVolumeForwardsToEngine() {
        let (vm, engine, _, _) = makeVM()
        vm.setVolume(0.4, for: "forest")
        #expect(engine.volumes["forest"] == 0.4)
        #expect(vm.volume(for: "forest") == 0.4)
    }

    @Test func sleepTimerStopsAllWhenElapsed() {
        let (vm, engine, clock, ticker) = makeVM()
        vm.toggle("rain")
        vm.startSleepTimer(minutes: 1)
        #expect(vm.sleepRemainingText == "01:00")
        clock.advance(by: 60); ticker.fire()
        #expect(engine.stopAllCount == 1)
        #expect(vm.sleepRemainingText == nil)
    }
}
