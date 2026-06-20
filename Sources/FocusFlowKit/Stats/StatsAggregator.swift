import Foundation

public struct DailyBucket: Equatable, Sendable {
    public let date: Date          // start-of-day
    public let sessionCount: Int
    public let totalFocus: TimeInterval
    public init(date: Date, sessionCount: Int, totalFocus: TimeInterval) {
        self.date = date; self.sessionCount = sessionCount; self.totalFocus = totalFocus
    }
}

public struct StatsSummary: Equatable, Sendable {
    public let totalFocus: TimeInterval
    public let dailyAverageSessions: Double
    public let currentStreakDays: Int
    public let bestStreakDays: Int
    public let last7Days: [DailyBucket]   // oldest -> newest, always 7 entries
}

/// Pure aggregation over completed focus sessions. No clock of its own — the
/// caller passes `now` so results are deterministic and testable.
public enum StatsAggregator {
    public static func summarize(
        _ sessions: [FocusSessionRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> StatsSummary {
        let totalFocus = sessions.reduce(0) { $0 + $1.duration }

        // Group sessions by start-of-day.
        var byDay: [Date: (count: Int, focus: TimeInterval)] = [:]
        for s in sessions {
            let key = calendar.startOfDay(for: s.startedAt)
            let cur = byDay[key] ?? (0, 0)
            byDay[key] = (cur.count + 1, cur.focus + s.duration)
        }

        // last 7 days, oldest -> newest, ending today.
        let today = calendar.startOfDay(for: now)
        var last7: [DailyBucket] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let agg = byDay[date] ?? (0, 0)
            last7.append(DailyBucket(date: date, sessionCount: agg.count, totalFocus: agg.focus))
        }

        let activeDays = byDay.count
        let dailyAverageSessions = activeDays == 0 ? 0 : Double(sessions.count) / Double(activeDays)

        let (current, best) = streaks(activeDays: Set(byDay.keys), today: today, calendar: calendar)

        return StatsSummary(
            totalFocus: totalFocus,
            dailyAverageSessions: dailyAverageSessions,
            currentStreakDays: current,
            bestStreakDays: best,
            last7Days: last7
        )
    }

    private static func streaks(activeDays: Set<Date>, today: Date, calendar: Calendar) -> (current: Int, best: Int) {
        guard !activeDays.isEmpty else { return (0, 0) }
        let sorted = activeDays.sorted()

        // Best streak: longest run of consecutive days anywhere.
        var best = 1, run = 1
        for i in 1..<max(sorted.count, 1) where sorted.count > 1 {
            let prev = sorted[i - 1], cur = sorted[i]
            if calendar.date(byAdding: .day, value: 1, to: prev).map({ calendar.isDate($0, inSameDayAs: cur) }) == true {
                run += 1; best = max(best, run)
            } else { run = 1 }
        }
        if sorted.count == 1 { best = 1 }

        // Current streak: consecutive days counting back from today.
        var current = 0
        var cursor = today
        while activeDays.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, best)
    }
}
