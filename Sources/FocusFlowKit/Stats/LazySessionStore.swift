import Foundation

/// Defers building the real session store — and with it the SwiftData
/// `ModelContainer`, its file I/O and migration check — until the first read
/// or write. That keeps the work off the app-launch path: the first write is
/// a completed focus session, minutes after launch.
///
/// A factory failure degrades to dropped writes and empty reads rather than
/// crashing, and is not retried.
@MainActor
public final class LazySessionStore: SessionRecording, SessionReading {
    private let make: () throws -> (SessionRecording & SessionReading)
    private var resolved: (SessionRecording & SessionReading)?
    private var failed = false

    public init(make: @escaping () throws -> (SessionRecording & SessionReading)) {
        self.make = make
    }

    private var store: (SessionRecording & SessionReading)? {
        if let resolved { return resolved }
        guard !failed else { return nil }
        do { resolved = try make() } catch { failed = true }
        return resolved
    }

    public var revision: Int { store?.revision ?? 0 }
    public func record(_ session: FocusSessionRecord) { store?.record(session) }
    public func allSessions() -> [FocusSessionRecord] { store?.allSessions() ?? [] }
}
