import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct LazySessionStoreTests {
    @Test func doesNotResolveOnConstruction() {
        var made = 0
        _ = LazySessionStore { made += 1; return SessionRecorderAndReaderSpy() }
        #expect(made == 0)
    }

    @Test func resolvesOnceAcrossManyUses() {
        var made = 0
        let store = LazySessionStore { made += 1; return SessionRecorderAndReaderSpy() }
        store.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        _ = store.allSessions()
        _ = store.revision
        #expect(made == 1)
    }

    @Test func passesWritesAndReadsThrough() {
        let spy = SessionRecorderAndReaderSpy()
        let store = LazySessionStore { spy }
        store.record(FocusSessionRecord(startedAt: Date(timeIntervalSince1970: 10), duration: 90))
        #expect(store.allSessions().count == 1)
        #expect(store.allSessions().first?.duration == 90)
        #expect(store.revision == 1)
    }

    @Test func degradesWhenTheFactoryThrows() {
        struct Boom: Error {}
        let store = LazySessionStore { throw Boom() }
        store.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        #expect(store.allSessions().isEmpty)
        #expect(store.revision == 0)
    }

    @Test func doesNotRetryAFailedFactory() {
        struct Boom: Error {}
        var attempts = 0
        let store = LazySessionStore { attempts += 1; throw Boom() }
        _ = store.allSessions()
        _ = store.allSessions()
        #expect(attempts == 1)
    }
}
