import Foundation
import Observation

/// Owns the to-do list for the UI and credits it on behalf of the timer.
///
/// The list is held in memory and written through to the store on each
/// mutation — loaded once, never refetched per tab visit.
///
/// The store resolves lazily: this view model is constructed at launch (the
/// timer needs it for attribution), but nothing opens the SwiftData container
/// until the list is first read. A store that fails to build is not retried,
/// and the list keeps working in memory for the session.
@MainActor
@Observable
public final class TasksViewModel: ActiveTaskProviding {
    @ObservationIgnored private let makeStore: () throws -> TaskStoring
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private var store: TaskStoring?
    @ObservationIgnored private var storeFailed = false
    @ObservationIgnored private var backing = TaskList()
    @ObservationIgnored private var hasLoaded = false

    /// The observable half of the state. Every mutation bumps it, and every
    /// accessor reads it, so views re-render on change. The list itself is
    /// observation-ignored precisely so the lazy first load — which may
    /// happen inside a view body — writes no observed state during an update.
    private var version = 0

    public init(store: @escaping () throws -> TaskStoring, clock: Clock = SystemClock()) {
        self.makeStore = store
        self.clock = clock
    }

    // MARK: Reads

    public var items: [TaskItem] { list.items }
    public var openItems: [TaskItem] { list.openItems }
    public var doneItems: [TaskItem] { list.doneItems }
    public var activeItem: TaskItem? { list.activeItem }
    public var activeTaskID: UUID? { list.activeID }

    private var list: TaskList {
        _ = version          // registers the observable dependency
        loadIfNeeded()
        return backing
    }

    // MARK: Intents

    public func add(_ title: String) {
        mutate { $0.add(title: title, createdAt: clock.now) }
    }

    public func rename(_ id: UUID, to title: String) { mutate { $0.rename(id, to: title) } }
    public func toggleDone(_ id: UUID) { mutate { $0.toggleDone(id) } }
    public func delete(_ id: UUID) { mutate { $0.delete(id) } }
    public func setActive(_ id: UUID?) { mutate { $0.setActive(id) } }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        mutate { $0.move(fromOffsets: source, toOffset: destination) }
    }

    public func creditFocusSession(to id: UUID) { mutate { $0.creditPomodoro(to: id) } }

    // MARK: Private

    /// Applies a change, then persists it. A no-op change (a blank title, an
    /// unknown id) neither bumps the version nor writes to the store.
    private func mutate(_ body: (inout TaskList) -> Void) {
        loadIfNeeded()
        var updated = backing
        body(&updated)
        guard updated != backing else { return }
        backing = updated
        version += 1
        store?.save(backing)
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if store == nil, !storeFailed {
            do { store = try makeStore() } catch { storeFailed = true }
        }
        if let store { backing = store.load() }
    }
}
