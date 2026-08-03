import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct SwiftDataSessionStoreTests {
    @Test func recordsAndReadsBackSessions() throws {
        let store = try SwiftDataSessionStore(inMemory: true)
        let start = Date(timeIntervalSince1970: 5_000)
        store.record(FocusSessionRecord(startedAt: start, duration: 1_500))
        store.record(FocusSessionRecord(startedAt: start.addingTimeInterval(3_600), duration: 600))

        let all = store.allSessions()
        #expect(all.count == 2)
        #expect(all.contains { $0.duration == 1_500 })
        #expect(all.contains { $0.duration == 600 })
    }

    @Test func startsEmpty() throws {
        let store = try SwiftDataSessionStore(inMemory: true)
        #expect(store.allSessions().isEmpty)
    }

    /// Guards the narrowed `propertiesToFetch`: `asRecord` reads `id`, so
    /// leaving it out of the fetched properties would fault every row back to
    /// the store.
    @Test func partialFetchStillCarriesIdStartAndDuration() throws {
        let store = try SwiftDataSessionStore(inMemory: true)
        let record = FocusSessionRecord(startedAt: Date(timeIntervalSince1970: 9_000), duration: 1_500)
        store.record(record)
        let read = try #require(store.allSessions().first)
        #expect(read.id == record.id)
        #expect(read.startedAt == record.startedAt)
        #expect(read.duration == record.duration)
    }

    @Test func revisionAdvancesOnEveryWrite() throws {
        let store = try SwiftDataSessionStore(inMemory: true)
        #expect(store.revision == 0)
        store.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        store.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        #expect(store.revision == 2)
    }
}
