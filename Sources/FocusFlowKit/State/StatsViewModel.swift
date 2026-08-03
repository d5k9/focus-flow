import Foundation
import Observation

@MainActor
@Observable
public final class StatsViewModel {
    public private(set) var summary: StatsSummary
    public private(set) var isEmpty: Bool

    @ObservationIgnored private let reader: SessionReading
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let calendar: Calendar
    /// What the current summary was computed from. `nil` until the first
    /// refresh, so the first call always aggregates.
    @ObservationIgnored private var cacheKey: CacheKey?

    private struct CacheKey: Equatable {
        let revision: Int
        let day: Date
    }

    public init(reader: SessionReading, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        self.reader = reader; self.clock = clock; self.calendar = calendar
        self.summary = StatsAggregator.summarize([], now: clock.now, calendar: calendar)
        self.isEmpty = true
    }

    /// Re-aggregates only when the data or the day has changed. The day is
    /// part of the key because the summary is relative to today: `last7Days`
    /// is a window ending today and the current streak counts back from it.
    /// Keying on the revision alone would leave an app left running overnight
    /// showing yesterday's window.
    public func refresh() {
        let key = CacheKey(revision: reader.revision, day: calendar.startOfDay(for: clock.now))
        guard key != cacheKey else { return }
        let sessions = reader.allSessions()
        summary = StatsAggregator.summarize(sessions, now: clock.now, calendar: calendar)
        isEmpty = sessions.isEmpty
        cacheKey = key
    }

    public var totalFocusText: String {
        let mins = Int(summary.totalFocus) / 60
        return "\(mins / 60)h \(mins % 60)m"
    }
    public var dailyAverageText: String { String(format: "%.1f", summary.dailyAverageSessions) }
    public var currentStreakText: String { "\(summary.currentStreakDays)" }
    public var bestStreakText: String { "\(summary.bestStreakDays)" }
}
