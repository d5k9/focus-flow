import Foundation
import SwiftData

/// SwiftData persistence record for a to-do item. Kept out of the pure
/// `TaskList` type, which stays Foundation-only.
///
/// `sortIndex` persists manual ordering and `isActive` persists the
/// selection; neither belongs in the domain type, where order is positional
/// and the selection is a single id.
@Model
public final class TaskEntity {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var completedPomodoros: Int
    public var createdAt: Date
    public var sortIndex: Int
    public var isActive: Bool

    public init(
        id: UUID,
        title: String,
        isDone: Bool,
        completedPomodoros: Int,
        createdAt: Date,
        sortIndex: Int,
        isActive: Bool
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.completedPomodoros = completedPomodoros
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.isActive = isActive
    }

    var asItem: TaskItem {
        TaskItem(id: id, title: title, isDone: isDone,
                 completedPomodoros: completedPomodoros, createdAt: createdAt)
    }
}
