import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct StatsViewModelTests {
    @MainActor final class StubReader: SessionReading {
        var sessions: [FocusSessionRecord] = []
        var revision = 0
        private(set) var fetchCount = 0
        func allSessions() -> [FocusSessionRecord] { fetchCount += 1; return sessions }
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

    // MARK: Caching

    @Test func refreshSkipsRefetchWhenNothingChanged() {
        let reader = StubReader()
        let vm = StatsViewModel(reader: reader, clock: FakeClock(), calendar: cal)
        vm.refresh(); vm.refresh(); vm.refresh()
        #expect(reader.fetchCount == 1)
    }

    @Test func refreshRefetchesAfterAWrite() {
        let reader = StubReader()
        let vm = StatsViewModel(reader: reader, clock: FakeClock(), calendar: cal)
        vm.refresh()
        reader.revision += 1
        vm.refresh()
        #expect(reader.fetchCount == 2)
    }

    /// The summary depends on today's date — a 7-day window ending today and a
    /// streak counted back from today — so the day is part of the cache key.
    @Test func refreshRefetchesAfterMidnight() {
        let start = DateComponents(calendar: cal, year: 2026, month: 6, day: 20, hour: 23).date!
        let reader = StubReader()
        let clock = FakeClock(start)
        let vm = StatsViewModel(reader: reader, clock: clock, calendar: cal)
        vm.refresh()
        clock.advance(by: 2 * 3600)      // crosses into the 21st
        vm.refresh()
        #expect(reader.fetchCount == 2)
    }

    @Test func refreshDoesNotRefetchLaterTheSameDay() {
        let start = DateComponents(calendar: cal, year: 2026, month: 6, day: 20, hour: 9).date!
        let reader = StubReader()
        let clock = FakeClock(start)
        let vm = StatsViewModel(reader: reader, clock: clock, calendar: cal)
        vm.refresh()
        clock.advance(by: 4 * 3600)      // still the 20th
        vm.refresh()
        #expect(reader.fetchCount == 1)
    }
}
