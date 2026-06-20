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

    public init(reader: SessionReading, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        self.reader = reader; self.clock = clock; self.calendar = calendar
        self.summary = StatsAggregator.summarize([], now: clock.now, calendar: calendar)
        self.isEmpty = true
    }

    public func refresh() {
        let sessions = reader.allSessions()
        summary = StatsAggregator.summarize(sessions, now: clock.now, calendar: calendar)
        isEmpty = sessions.isEmpty
    }

    public var totalFocusText: String {
        let mins = Int(summary.totalFocus) / 60
        return "\(mins / 60)h \(mins % 60)m"
    }
    public var dailyAverageText: String { String(format: "%.1f", summary.dailyAverageSessions) }
    public var currentStreakText: String { "\(summary.currentStreakDays)" }
    public var bestStreakText: String { "\(summary.bestStreakDays)" }
}
