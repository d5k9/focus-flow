import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct StatsViewModelTests {
    @MainActor final class StubReader: SessionReading {
        var sessions: [FocusSessionRecord] = []
        func allSessions() -> [FocusSessionRecord] { sessions }
    }
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func isEmptyWhenNoSessions() {
        let vm = StatsViewModel(reader: StubReader(), clock: FakeClock(), calendar: cal)
        vm.refresh()
        #expect(vm.isEmpty)
    }

    @Test func formatsTotalsAfterRefresh() {
        let reader = StubReader()
        let now = DateComponents(calendar: cal, year: 2026, month: 6, day: 20, hour: 12).date!
        reader.sessions = [FocusSessionRecord(startedAt: now, duration: 90 * 60)]   // 1h30m
        let clock = FakeClock(now)
        let vm = StatsViewModel(reader: reader, clock: clock, calendar: cal)
        vm.refresh()
        #expect(!vm.isEmpty)
        #expect(vm.totalFocusText == "1h 30m")
    }
}
