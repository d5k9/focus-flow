import Foundation
import SwiftData

@MainActor
public final class SwiftDataTaskStore: TaskStoring {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public convenience init(inMemory: Bool = false) throws {
        self.init(container: try AppModelContainer.make(inMemory: inMemory))
    }

    /// Rebuilds the list in `sortIndex` order; `TaskList.init` then partitions
    /// open items before done ones, preserving relative order within each
    /// group. (Sorting on `isDone` in the fetch is not an option — `Bool` is
    /// not `Comparable`, so `SortDescriptor` cannot take it.)
    ///
    /// Defensive about an invariant the schema cannot enforce: if several rows
    /// claim `isActive` — say a crash landed between writes — the first in
    /// sort order wins and the rest are dropped on the next save.
    public func load() -> TaskList {
        let descriptor = FetchDescriptor<TaskEntity>(sortBy: [SortDescriptor(\.sortIndex)])
        let rows = (try? context.fetch(descriptor)) ?? []
        let activeID = rows.first { $0.isActive && !$0.isDone }?.id
        return TaskList(items: rows.map(\.asItem), activeID: activeID)
    }

    /// Replaces all rows. The list is tens of items, so a full rewrite is
    /// simpler than diffing and fast enough at this scale.
    public func save(_ list: TaskList) {
        do {
            try context.delete(model: TaskEntity.self)
            for (index, item) in list.items.enumerated() {
                context.insert(TaskEntity(
                    id: item.id,
                    title: item.title,
                    isDone: item.isDone,
                    completedPomodoros: item.completedPomodoros,
                    createdAt: item.createdAt,
                    sortIndex: index,
                    isActive: item.id == list.activeID))
            }
            try context.save()
        } catch {
            // Best-effort, as with sessions: never crash on persistence failure.
        }
    }
}
