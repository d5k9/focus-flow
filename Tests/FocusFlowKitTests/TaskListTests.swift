import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct TaskListTests {
    private func list(_ titles: String...) -> TaskList {
        var l = TaskList()
        for (i, t) in titles.enumerated() {
            _ = l.add(title: t, createdAt: Date(timeIntervalSince1970: TimeInterval(i)))
        }
        return l
    }

    // MARK: Adding

    @Test func addsTrimmedTitles() {
        var l = TaskList()
        _ = l.add(title: "  Write spec  ", createdAt: Date())
        #expect(l.items.map(\.title) == ["Write spec"])
    }

    @Test func ignoresEmptyTitles() {
        var l = TaskList()
        #expect(l.add(title: "   ", createdAt: Date()) == nil)
        #expect(l.items.isEmpty)
    }

    @Test func newItemsStartOpenWithNoPomodoros() {
        let l = list("a")
        #expect(l.items[0].isDone == false)
        #expect(l.items[0].completedPomodoros == 0)
    }

    // MARK: Ordering

    @Test func doneItemsSinkBelowOpenOnes() {
        var l = list("a", "b", "c")
        l.toggleDone(l.items[0].id)
        #expect(l.items.map(\.title) == ["b", "c", "a"])
        #expect(l.openItems.map(\.title) == ["b", "c"])
        #expect(l.doneItems.map(\.title) == ["a"])
    }

    @Test func moveReordersWithinOpenItemsOnly() {
        var l = list("a", "b", "c")
        l.toggleDone(l.items[0].id)          // a done; open == [b, c]
        l.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(l.openItems.map(\.title) == ["c", "b"])
        #expect(l.items.map(\.title) == ["c", "b", "a"])
    }

    // MARK: Active selection

    @Test func completingTheActiveItemClearsActive() {
        var l = list("a", "b")
        let id = l.items[0].id
        l.setActive(id)
        l.toggleDone(id)
        #expect(l.activeID == nil)
    }

    @Test func unmarkingDoesNotRestoreActive() {
        var l = list("a")
        let id = l.items[0].id
        l.setActive(id); l.toggleDone(id); l.toggleDone(id)
        #expect(l.activeID == nil)
        #expect(l.items[0].isDone == false)
    }

    @Test func deletingTheActiveItemClearsActive() {
        var l = list("a", "b")
        let id = l.items[0].id
        l.setActive(id)
        l.delete(id)
        #expect(l.activeID == nil)
        #expect(l.items.count == 1)
    }

    @Test func aDoneItemCannotBecomeActive() {
        var l = list("a")
        let id = l.items[0].id
        l.toggleDone(id)
        l.setActive(id)
        #expect(l.activeID == nil)
    }

    @Test func activeItemResolvesToTheItem() {
        var l = list("a", "b")
        l.setActive(l.items[1].id)
        #expect(l.activeItem?.title == "b")
    }

    @Test func initDropsAnActiveIdThatIsNotAnOpenItem() {
        let orphan = UUID()
        let l = TaskList(items: [TaskItem(title: "a", createdAt: Date())], activeID: orphan)
        #expect(l.activeID == nil)
    }

    // MARK: Credit

    @Test func creditIncrementsTheCounter() {
        var l = list("a")
        let id = l.items[0].id
        l.creditPomodoro(to: id)
        l.creditPomodoro(to: id)
        #expect(l.items[0].completedPomodoros == 2)
    }

    @Test func creditForUnknownIdIsIgnored() {
        var l = list("a")
        l.creditPomodoro(to: UUID())
        #expect(l.items[0].completedPomodoros == 0)
    }

    @Test func doneItemKeepsItsCount() {
        var l = list("a")
        let id = l.items[0].id
        l.creditPomodoro(to: id)
        l.toggleDone(id)
        #expect(l.items[0].completedPomodoros == 1)
    }

    // MARK: Renaming

    @Test func renameTrimsAndIgnoresEmpty() {
        var l = list("a")
        let id = l.items[0].id
        l.rename(id, to: "  b ")
        #expect(l.items[0].title == "b")
        l.rename(id, to: "  ")
        #expect(l.items[0].title == "b")
    }
}
