import Foundation

/// A single completed focus session. Pure value type — the unit the stats
/// aggregator and the SwiftData store both speak in.
public struct FocusSessionRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let duration: TimeInterval
    /// The task this session was attributed to, if one was active. This is
    /// the durable record of the attribution — `TaskItem.completedPomodoros`
    /// is a cache of it.
    public let taskID: UUID?

    public init(id: UUID = UUID(), startedAt: Date, duration: TimeInterval, taskID: UUID? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.taskID = taskID
    }
}
