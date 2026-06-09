import Foundation
@testable import FocusFlowKit

/// A clock whose `now` is fully controlled by the test.
final class FakeClock: Clock {
    var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_000_000)) { current = start }
    var now: Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

/// A ticker that records start/stop and lets the test fire ticks by hand.
final class FakeTicker: TimerTicker {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var isRunning = false
    private var onTick: (() -> Void)?

    func start(onTick: @escaping () -> Void) {
        startCount += 1
        isRunning = true
        self.onTick = onTick
    }
    func stop() {
        stopCount += 1
        isRunning = false
        onTick = nil
    }
    /// Simulate one ticker fire.
    func fire() { onTick?() }
}
