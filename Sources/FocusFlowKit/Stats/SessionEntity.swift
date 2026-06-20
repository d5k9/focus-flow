import Foundation
import SwiftData

/// SwiftData persistence record for a completed focus session. Kept out of
/// `Domain/` so the domain layer stays Foundation-only.
@Model
public final class SessionEntity {
    public var id: UUID
    public var startedAt: Date
    public var duration: TimeInterval

    public init(id: UUID, startedAt: Date, duration: TimeInterval) {
        self.id = id; self.startedAt = startedAt; self.duration = duration
    }

    var asRecord: FocusSessionRecord {
        FocusSessionRecord(id: id, startedAt: startedAt, duration: duration)
    }
}

@MainActor
public final class SwiftDataSessionStore: SessionRecording, SessionReading {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: SessionEntity.self, configurations: config)
    }

    public func record(_ session: FocusSessionRecord) {
        context.insert(SessionEntity(id: session.id, startedAt: session.startedAt, duration: session.duration))
        try? context.save()   // best-effort; never crash on persistence failure
    }

    public func allSessions() -> [FocusSessionRecord] {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.asRecord)
    }
}
