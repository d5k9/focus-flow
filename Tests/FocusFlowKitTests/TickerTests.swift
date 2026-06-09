import Testing
import Foundation
@testable import FocusFlowKit

@Suite struct ClockAndTickerTests {
    @Test func systemClockReturnsAdvancingTime() async throws {
        let clock = SystemClock()
        let first = clock.now
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        #expect(clock.now >= first)
    }

    @Test func dispatchTickerFiresThenStops() async throws {
        let ticker = DispatchSourceTimerTicker(
            queue: .global(), interval: 0.05, leeway: .milliseconds(10))
        let box = TickBox()
        ticker.start { box.increment() }
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms -> ~3-4 ticks
        ticker.stop()
        let afterStop = box.value
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(box.value >= 2)            // it fired
        #expect(box.value == afterStop)    // and stopped cleanly
    }
}

/// Thread-safe counter for the async ticker test.
final class TickBox: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
