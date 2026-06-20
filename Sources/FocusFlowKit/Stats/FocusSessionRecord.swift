import Foundation

/// A single completed focus session. Pure value type — the unit the stats
/// aggregator and the SwiftData store both speak in.
public struct FocusSessionRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let duration: TimeInterval

    public init(id: UUID = UUID(), startedAt: Date, duration: TimeInterval) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
    }
}
