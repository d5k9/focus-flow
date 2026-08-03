import Foundation

/// The timer's entire view of the to-do list: which task is active, and a way
/// to credit it when a focus session completes. Keeping it this narrow means
/// `TimerViewModel` stays headless — it knows the protocol, not the store.
@MainActor
public protocol ActiveTaskProviding: AnyObject {
    var activeTaskID: UUID? { get }
    func creditFocusSession(to id: UUID)
}
