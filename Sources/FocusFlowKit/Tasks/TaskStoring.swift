import Foundation

/// Load/save seam for the to-do list. `@MainActor` for the same reason as
/// `SessionRecording` — its only conformer and its only caller are both
/// main-actor isolated. The view model depends on this, not on SwiftData,
/// so it can be tested with a spy.
@MainActor
public protocol TaskStoring: AnyObject {
    func load() -> TaskList
    func save(_ list: TaskList)
}
