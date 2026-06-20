import Foundation
import Observation

@MainActor
@Observable
public final class SoundMixerViewModel {
    private struct Layer { var isOn: Bool; var volume: Double }
    private var layers: [String: Layer] = [:]
    public private(set) var sleepRemaining: TimeInterval?

    @ObservationIgnored private let engine: AmbientAudioEngine
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let ticker: TimerTicker
    @ObservationIgnored private var sleepEnd: Date?

    public init(engine: AmbientAudioEngine, clock: Clock = SystemClock(), ticker: TimerTicker) {
        self.engine = engine; self.clock = clock; self.ticker = ticker
    }

    public func isOn(_ id: String) -> Bool { layers[id]?.isOn ?? false }
    public func volume(for id: String) -> Double { layers[id]?.volume ?? 0.7 }

    public func toggle(_ id: String) {
        var layer = layers[id] ?? Layer(isOn: false, volume: 0.7)
        layer.isOn.toggle()
        layers[id] = layer
        if layer.isOn { engine.setVolume(layer.volume, for: id); engine.play(id) }
        else { engine.stop(id) }
    }

    public func setVolume(_ v: Double, for id: String) {
        var layer = layers[id] ?? Layer(isOn: false, volume: v)
        layer.volume = v; layers[id] = layer
        engine.setVolume(v, for: id)
    }

    public func startSleepTimer(minutes: Int) {
        sleepEnd = clock.now.addingTimeInterval(TimeInterval(minutes) * 60)
        sleepRemaining = TimeInterval(minutes) * 60
        ticker.start { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { self.tickSleep() }
        }
    }

    public func cancelSleepTimer() {
        ticker.stop(); sleepEnd = nil; sleepRemaining = nil
    }

    public var sleepRemainingText: String? {
        guard let r = sleepRemaining else { return nil }
        let s = max(0, Int(r.rounded(.up))); return String(format: "%02d:%02d", s / 60, s % 60)
    }

    func tickSleep() {
        guard let end = sleepEnd else { return }
        sleepRemaining = max(0, end.timeIntervalSince(clock.now))
        if sleepRemaining! <= 0 { engine.stopAll(); cancelSleepTimer() }
    }
}
