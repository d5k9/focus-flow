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
}
