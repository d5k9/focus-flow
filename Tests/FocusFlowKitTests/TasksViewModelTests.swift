import Foundation
import Testing
@testable import FocusFlowKit

@MainActor final class TaskStoreSpy: TaskStoring {
    var stored = TaskList()
    private(set) var saveCount = 0
    private(set) var loadCount = 0
    func load() -> TaskList { loadCount += 1; return stored }
    func save(_ list: TaskList) { saveCount += 1; stored = list }
}

@MainActor
@Suite struct TasksViewModelTests {
    /// The view model is built at launch, so construction must not open the
    /// store — that is the whole point of the lazy launch path.
    @Test func doesNotTouchTheStoreUntilFirstAccess() {
        var made = 0
        _ = TasksViewModel(store: { made += 1; return TaskStoreSpy() })
        #expect(made == 0)
    }

    @Test func loadsOnceAcrossRepeatedReads() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        _ = vm.items; _ = vm.items; _ = vm.activeTaskID
        #expect(spy.loadCount == 1)
    }

    @Test func restoresPersistedState() {
        let spy = TaskStoreSpy()
        var seed = TaskList()
        let id = seed.add(title: "seeded", createdAt: Date())!
        seed.setActive(id)
        spy.stored = seed
        let vm = TasksViewModel(store: { spy })
        #expect(vm.items.map(\.title) == ["seeded"])
        #expect(vm.activeTaskID == id)
    }

    @Test func writesThroughOnEveryMutation() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        vm.add("write spec")
        #expect(spy.saveCount == 1)
        #expect(spy.stored.items.map(\.title) == ["write spec"])

        vm.setActive(vm.items[0].id)
        #expect(spy.saveCount == 2)
        #expect(spy.stored.activeID == vm.items[0].id)

        vm.toggleDone(vm.items[0].id)
        #expect(spy.saveCount == 3)
        #expect(spy.stored.items[0].isDone)

        vm.delete(vm.items[0].id)
        #expect(spy.saveCount == 4)
        #expect(spy.stored.items.isEmpty)
    }

    @Test func blankTitlesAreNotAdded() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        vm.add("   ")
        #expect(vm.items.isEmpty)
        #expect(spy.saveCount == 0)
    }

    @Test func creditingAFocusSessionPersists() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        vm.add("a")
        let id = vm.items[0].id
        vm.creditFocusSession(to: id)
        #expect(vm.items[0].completedPomodoros == 1)
        #expect(spy.stored.items[0].completedPomodoros == 1)
    }

    @Test func activeTaskIDTracksTheSelection() {
        let vm = TasksViewModel(store: { TaskStoreSpy() })
        vm.add("a")
        #expect(vm.activeTaskID == nil)
        vm.setActive(vm.items[0].id)
        #expect(vm.activeTaskID == vm.items[0].id)
        #expect(vm.activeItem?.title == "a")
    }

    @Test func fallsBackToMemoryWhenTheStoreIsUnavailable() {
        struct Boom: Error {}
        let vm = TasksViewModel(store: { throw Boom() })
        vm.add("a")
        #expect(vm.items.map(\.title) == ["a"])
        vm.setActive(vm.items[0].id)
        #expect(vm.activeTaskID == vm.items[0].id)
    }

    @Test func doesNotRetryAFailedStore() {
        struct Boom: Error {}
        var attempts = 0
        let vm = TasksViewModel(store: { attempts += 1; throw Boom() })
        vm.add("a")
        vm.add("b")
        #expect(attempts == 1)
    }
}
