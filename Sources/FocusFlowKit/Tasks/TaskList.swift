import Foundation

/// A single to-do item. `completedPomodoros` is a denormalized cache of the
/// focus sessions attributed to this item — the durable record of those
/// sessions is `FocusSessionRecord.taskID`.
public struct TaskItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public var completedPomodoros: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        completedPomodoros: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.completedPomodoros = completedPomodoros
        self.createdAt = createdAt
    }
}

/// Ordering and active-selection rules for the to-do list. Pure value type —
/// no clock, no storage — so the rules are testable in isolation, in the same
/// spirit as `PomodoroEngine`.
///
/// Invariants: `items` is always open-first then done, stable within each
/// group; `activeID`, when set, always names an open item.
public struct TaskList: Equatable, Sendable {
    public private(set) var items: [TaskItem]
    public private(set) var activeID: UUID?

    public init(items: [TaskItem] = [], activeID: UUID? = nil) {
        self.items = items
        self.activeID = activeID
        normalize()
        if let activeID, !self.items.contains(where: { $0.id == activeID && !$0.isDone }) {
            self.activeID = nil
        }
    }

    public var openItems: [TaskItem] { items.filter { !$0.isDone } }
    public var doneItems: [TaskItem] { items.filter(\.isDone) }
    public var activeItem: TaskItem? { activeID.flatMap { id in items.first { $0.id == id } } }

    /// Appends a task. Returns its id, or nil when the title is blank.
    @discardableResult
    public mutating func add(title: String, createdAt: Date) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TaskItem(title: trimmed, createdAt: createdAt)
        items.append(item)
        normalize()
        return item.id
    }

    /// Blank titles are ignored rather than blanking the task.
    public mutating func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = index(of: id) else { return }
        items[i].title = trimmed
    }

    /// Completing the active task clears the selection; un-completing it does
    /// not bring the selection back.
    public mutating func toggleDone(_ id: UUID) {
        guard let i = index(of: id) else { return }
        items[i].isDone.toggle()
        if items[i].isDone, activeID == id { activeID = nil }
        normalize()
    }

    public mutating func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        if activeID == id { activeID = nil }
    }

    /// Only an open item can be active. Passing nil, an unknown id, or a done
    /// item clears the selection.
    public mutating func setActive(_ id: UUID?) {
        guard let id, let i = index(of: id), !items[i].isDone else {
            activeID = nil
            return
        }
        activeID = id
    }

    /// Offsets index into `openItems`, matching what the list UI offers —
    /// done items are not reorderable. Follows SwiftUI's `onMove` convention,
    /// where `destination` is an index into the list *before* removal. The
    /// arithmetic is spelled out here rather than borrowed from SwiftUI's
    /// `move(fromOffsets:toOffset:)` so this file stays Foundation-only.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var open = openItems
        let valid = source.filter { open.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.map { open[$0] }
        for i in valid.sorted(by: >) { open.remove(at: i) }
        let insertAt = destination - valid.count(where: { $0 < destination })
        open.insert(contentsOf: moving, at: min(max(0, insertAt), open.count))
        items = open + doneItems
    }

    /// Credits one completed focus session. An unknown id is ignored: the
    /// task may have been deleted while the session was running.
    public mutating func creditPomodoro(to id: UUID) {
        guard let i = index(of: id) else { return }
        items[i].completedPomodoros += 1
    }

    private func index(of id: UUID) -> Int? { items.firstIndex { $0.id == id } }

    /// Stable partition: open items keep their relative order, done items follow.
    private mutating func normalize() {
        items = items.filter { !$0.isDone } + items.filter(\.isDone)
    }
}
