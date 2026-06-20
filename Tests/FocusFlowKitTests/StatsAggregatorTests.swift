import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct StatsAggregatorTests {
    // Fixed calendar in UTC so day-bucketing is deterministic.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        DateComponents(calendar: cal, year: y, month: m, day: d, hour: hour).date!
    }

    @Test func emptyInputYieldsZeroes() {
        let s = StatsAggregator.summarize([], now: day(2026, 6, 20), calendar: cal)
        #expect(s.totalFocus == 0)
        #expect(s.currentStreakDays == 0)
        #expect(s.bestStreakDays == 0)
        #expect(s.last7Days.count == 7)
        #expect(s.last7Days.allSatisfy { $0.sessionCount == 0 })
    }

    @Test func totalsSumAllSessions() {
        let sessions = [
            FocusSessionRecord(startedAt: day(2026, 6, 20), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 20), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 19), duration: 600),
        ]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.totalFocus == 3_600)
    }

    @Test func last7DaysIsOldestToNewestAndBucketsByDay() {
        let sessions = [
            FocusSessionRecord(startedAt: day(2026, 6, 20, hour: 9), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 20, hour: 17), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 18), duration: 1_500),
        ]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.last7Days.count == 7)
        #expect(s.last7Days.last?.sessionCount == 2)        // today
        #expect(s.last7Days.last?.totalFocus == 3_000)
        #expect(cal.isDate(s.last7Days.last!.date, inSameDayAs: day(2026, 6, 20)))
    }

    @Test func currentStreakCountsConsecutiveDaysEndingToday() {
        let sessions = [
            FocusSessionRecord(startedAt: day(2026, 6, 20), duration: 1),
            FocusSessionRecord(startedAt: day(2026, 6, 19), duration: 1),
            FocusSessionRecord(startedAt: day(2026, 6, 18), duration: 1),
            // gap on the 17th
            FocusSessionRecord(startedAt: day(2026, 6, 16), duration: 1),
        ]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.currentStreakDays == 3)
        #expect(s.bestStreakDays == 3)
    }

    @Test func currentStreakIsZeroWhenNoSessionToday() {
        let sessions = [FocusSessionRecord(startedAt: day(2026, 6, 18), duration: 1)]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.currentStreakDays == 0)
    }
}
