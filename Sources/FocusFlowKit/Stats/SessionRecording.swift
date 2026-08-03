import Foundation

// These two protocols are `@MainActor` (unlike the older `SoundPlaying` /
// `NotificationScheduling` service protocols) because their only conformer is
// the `@MainActor` `SwiftDataSessionStore` and their only callers are the
// `@MainActor` view models — annotating them keeps the conformance isolation
// coherent and warning-free under Swift 6. Any test double conforming to these
// must therefore also be `@MainActor`.

/// Persists completed focus sessions. The view model depends only on this,
/// so it stays headless and testable with a spy.
@MainActor
public protocol SessionRecording: AnyObject {
    func record(_ session: FocusSessionRecord)
}

/// Reads back persisted sessions for the stats view.
@MainActor
public protocol SessionReading: AnyObject {
    func allSessions() -> [FocusSessionRecord]

    /// Bumped on every successful write. Lets a reader-side cache tell
    /// "nothing has changed" from "I have not looked yet" without refetching
    /// and re-aggregating the whole history.
    var revision: Int { get }
}
