import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct SwiftDataTaskStoreTests {
    @Test func startsEmpty() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        #expect(store.load().items.isEmpty)
    }

    @Test func roundTripsItemsOrderAndActiveSelection() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        var list = TaskList()
        let a = list.add(title: "a", createdAt: Date(timeIntervalSince1970: 1))!
        _ = list.add(title: "b", createdAt: Date(timeIntervalSince1970: 2))
        list.creditPomodoro(to: a)
        list.setActive(a)
        store.save(list)

        let loaded = store.load()
        #expect(loaded.items.map(\.title) == ["a", "b"])
        #expect(loaded.activeID == a)
        #expect(loaded.items[0].completedPomodoros == 1)
    }

    @Test func savePreservesDoneItemsAtTheBottom() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        var list = TaskList()
        let a = list.add(title: "a", createdAt: Date(timeIntervalSince1970: 1))!
        _ = list.add(title: "b", createdAt: Date(timeIntervalSince1970: 2))
        list.toggleDone(a)
        store.save(list)

        let loaded = store.load()
        #expect(loaded.items.map(\.title) == ["b", "a"])
        #expect(loaded.items[1].isDone)
    }

    @Test func saveReplacesPreviousState() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        var list = TaskList()
        _ = list.add(title: "a", createdAt: Date())
        store.save(list)
        list.delete(list.items[0].id)
        _ = list.add(title: "b", createdAt: Date())
        store.save(list)
        #expect(store.load().items.map(\.title) == ["b"])
    }

    @Test func preservesManualOrderAcrossReloads() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        var list = TaskList()
        _ = list.add(title: "a", createdAt: Date(timeIntervalSince1970: 1))
        _ = list.add(title: "b", createdAt: Date(timeIntervalSince1970: 2))
        _ = list.add(title: "c", createdAt: Date(timeIntervalSince1970: 3))
        list.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)   // c, a, b
        store.save(list)
        #expect(store.load().items.map(\.title) == ["c", "a", "b"])
    }

    @Test func sessionsAndTasksShareOneContainer() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let tasks = SwiftDataTaskStore(container: container)
        let sessions = SwiftDataSessionStore(container: container)
        var list = TaskList()
        _ = list.add(title: "a", createdAt: Date())
        tasks.save(list)
        sessions.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        #expect(tasks.load().items.count == 1)
        #expect(sessions.allSessions().count == 1)
    }
}
