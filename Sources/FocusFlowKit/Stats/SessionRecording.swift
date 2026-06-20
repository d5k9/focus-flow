import Foundation

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
}
