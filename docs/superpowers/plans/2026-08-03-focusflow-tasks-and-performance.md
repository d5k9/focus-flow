# FocusFlow Task List & Performance Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a to-do list whose items are credited for completed focus sessions, preceded by three targeted performance fixes to existing code.

**Architecture:** Domain logic (`TaskList`) is a pure value type in `FocusFlowKit` alongside `PomodoroEngine`; persistence is SwiftData behind a `TaskStoring` protocol sharing one `ModelContainer` with sessions; `TimerViewModel` learns about tasks only through a narrow `ActiveTaskProviding` protocol. The performance work lands first as its own commits so its measurements aren't confounded by the feature.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode, SwiftUI, `@Observable`, SwiftData, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-03-focusflow-tasks-and-performance-design.md`

## Global Constraints

- Kit code is Foundation-only in `Domain/`; Apple-framework deps allowed elsewhere in the kit.
- Kit tests run with `swift test`; app builds with `xcodegen generate` then `xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- Never edit `FocusFlow.xcodeproj` — it is generated and gitignored. Edit `project.yml`.
- New view-model/store protocols are `@MainActor` (per the rationale in `Sources/FocusFlowKit/Stats/SessionRecording.swift`).
- Persistence failures are best-effort and never fatal.
- No new design tokens — use `DesignTokens`.
- Part 1 tasks (1–5) commit before Part 2 tasks (6–13).

---

### Task 1: Split `TimerReadout` out of `TimerPopoverView`

**Files:**
- Create: `Features/Timer/TimerReadout.swift`
- Modify: `Features/Timer/TimerPopoverView.swift:38-52` (remove `ringSection`)

**Interfaces:**
- Produces: `struct TimerReadout: View { init(vm: TimerViewModel) }`

- [x] **Step 1: Create `TimerReadout`** — it takes the view model, not pre-read values:

```swift
import SwiftUI
import FocusFlowKit

/// The only view that reads per-second timer state. Kept separate from
/// `TimerPopoverView` so a tick invalidates this body alone, not the whole
/// popover. Passing `vm.progress`/`vm.displayTime` in from the parent would
/// move the observable read back up and undo that.
struct TimerReadout: View {
    let vm: TimerViewModel

    var body: some View {
        ZStack {
            ProgressRing(progress: vm.progress, tint: DesignTokens.accent(for: vm.phase))
            VStack(spacing: 2) {
                Text(vm.displayTime).font(DesignTokens.timerDisplay)
                Text(vm.phase.title.uppercased())
                    .font(DesignTokens.labelCaps)
                    .tracking(0.5)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .frame(width: 160, height: 160)
        .padding(.vertical, DesignTokens.stackTight)
    }
}
```

- [x] **Step 2: Delete `ringSection` from `TimerPopoverView` and call `TimerReadout(vm: vm)` in its place.** Confirm no remaining reference to `vm.displayTime` or `vm.progress` in `TimerPopoverView.swift` (`grep -n 'displayTime\|progress' Features/Timer/TimerPopoverView.swift` must return nothing).
- [x] **Step 3: Build** — `xcodegen generate && xcodebuild ... build`. Expected: BUILD SUCCEEDED.
- [x] **Step 4: Commit** — `perf(timer): scope per-tick invalidation to the readout view`

---

### Task 2: Date-aware stats cache

**Files:**
- Modify: `Sources/FocusFlowKit/Stats/SessionRecording.swift` (add `revision` to `SessionReading`)
- Modify: `Sources/FocusFlowKit/Stats/SessionEntity.swift` (increment on write)
- Modify: `Sources/FocusFlowKit/State/StatsViewModel.swift`
- Test: `Tests/FocusFlowKitTests/StatsViewModelTests.swift`

**Interfaces:**
- Produces: `SessionReading.revision: Int`; `StatsViewModel.refresh()` no-ops unless `(revision, startOfDay(now))` changed.

- [x] **Step 1: Write the failing tests.** Extend `StubReader` with `revision` and a fetch counter:

```swift
@MainActor final class StubReader: SessionReading {
    var sessions: [FocusSessionRecord] = []
    var revision = 0
    private(set) var fetchCount = 0
    func allSessions() -> [FocusSessionRecord] { fetchCount += 1; return sessions }
}

@Test func refreshSkipsRefetchWhenNothingChanged() {
    let reader = StubReader()
    let vm = StatsViewModel(reader: reader, clock: FakeClock(), calendar: cal)
    vm.refresh(); vm.refresh(); vm.refresh()
    #expect(reader.fetchCount == 1)
}

@Test func refreshRefetchesAfterAWrite() {
    let reader = StubReader()
    let vm = StatsViewModel(reader: reader, clock: FakeClock(), calendar: cal)
    vm.refresh()
    reader.revision += 1
    vm.refresh()
    #expect(reader.fetchCount == 2)
}

@Test func refreshRefetchesAfterMidnight() {
    let reader = StubReader()
    let clock = FakeClock(DateComponents(calendar: cal, year: 2026, month: 6, day: 20, hour: 23).date!)
    let vm = StatsViewModel(reader: reader, clock: clock, calendar: cal)
    vm.refresh()
    clock.advance(by: 2 * 3600)      // crosses into the 21st
    vm.refresh()
    #expect(reader.fetchCount == 2)
}
```

- [x] **Step 2: Run and watch them fail** — `swift test --filter StatsViewModelTests`. Expected: compile failure (`revision` not in protocol), then assertion failures.
- [x] **Step 3: Implement.** Add `var revision: Int { get }` to `SessionReading`; `SwiftDataSessionStore` gets `public private(set) var revision = 0` incremented at the end of `record`. In `StatsViewModel`:

```swift
@ObservationIgnored private var cacheKey: (revision: Int, day: Date)?

public func refresh() {
    let key = (reader.revision, calendar.startOfDay(for: clock.now))
    if let cacheKey, cacheKey == key { return }
    let sessions = reader.allSessions()
    summary = StatsAggregator.summarize(sessions, now: clock.now, calendar: calendar)
    isEmpty = sessions.isEmpty
    cacheKey = key
}
```

- [x] **Step 4: Run tests** — `swift test`. Expected: all pass (existing `EmptySessionReader` in `App/AppDelegate.swift` also needs `revision`; it is removed in Task 4, so add `var revision: Int { 0 }` to it now to keep the app compiling).
- [x] **Step 5: Commit** — `perf(stats): cache aggregation on (revision, day) instead of refetching per visit`

---

### Task 3: Narrow the stats fetch

**Files:**
- Modify: `Sources/FocusFlowKit/Stats/SessionEntity.swift:allSessions`
- Test: `Tests/FocusFlowKitTests/SwiftDataSessionStoreTests.swift`

- [x] **Step 1: Write the failing test** — proves the partial fetch still yields whole records:

```swift
@Test func partialFetchStillCarriesIdStartAndDuration() throws {
    let store = try SwiftDataSessionStore(inMemory: true)
    let record = FocusSessionRecord(startedAt: Date(timeIntervalSince1970: 9_000), duration: 1_500)
    store.record(record)
    let read = try #require(store.allSessions().first)
    #expect(read.id == record.id)
    #expect(read.startedAt == record.startedAt)
    #expect(read.duration == record.duration)
}
```

- [x] **Step 2: Run it** — `swift test --filter SwiftDataSessionStoreTests`. Expected: PASS already (this test guards the next step from regressing).
- [x] **Step 3: Add the narrowing.** `id` is included deliberately — `asRecord` reads it, and omitting it faults every row back to the store:

```swift
var descriptor = FetchDescriptor<SessionEntity>(
    sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
descriptor.propertiesToFetch = [\.id, \.startedAt, \.duration]
return ((try? context.fetch(descriptor)) ?? []).map(\.asRecord)
```

- [x] **Step 4: Run tests** — `swift test --filter SwiftDataSessionStoreTests`. Expected: PASS. If `propertiesToFetch` misbehaves on this SDK, revert this step alone and note it — Task 2 is the load-bearing fix.
- [x] **Step 5: Commit** — `perf(stats): fetch only the properties the aggregator reads`

---

### Task 4: `LazySessionStore`

**Files:**
- Create: `Sources/FocusFlowKit/Stats/LazySessionStore.swift`
- Test: `Tests/FocusFlowKitTests/LazySessionStoreTests.swift`

**Interfaces:**
- Produces: `LazySessionStore(make: @escaping () throws -> (SessionRecording & SessionReading))`, conforming to `SessionRecording, SessionReading`.

- [x] **Step 1: Write the failing tests:**

```swift
@MainActor
@Suite struct LazySessionStoreTests {
    @Test func doesNotResolveOnConstruction() {
        var made = 0
        _ = LazySessionStore { made += 1; return SessionRecorderAndReaderSpy() }
        #expect(made == 0)
    }

    @Test func resolvesOnceOnFirstUse() {
        var made = 0
        let store = LazySessionStore { made += 1; return SessionRecorderAndReaderSpy() }
        store.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        _ = store.allSessions()
        #expect(made == 1)
    }

    @Test func degradesWhenTheFactoryThrows() {
        struct Boom: Error {}
        let store = LazySessionStore { throw Boom() }
        store.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        #expect(store.allSessions().isEmpty)
        #expect(store.revision == 0)
    }
}
```

Add to `Support/Fakes.swift`:

```swift
@MainActor final class SessionRecorderAndReaderSpy: SessionRecording, SessionReading {
    private(set) var recorded: [FocusSessionRecord] = []
    var revision = 0
    func record(_ session: FocusSessionRecord) { recorded.append(session); revision += 1 }
    func allSessions() -> [FocusSessionRecord] { recorded }
}
```

- [x] **Step 2: Run and watch fail** — `swift test --filter LazySessionStoreTests`. Expected: compile failure, type not found.
- [x] **Step 3: Implement:**

```swift
import Foundation

/// Defers building the real session store (and its `ModelContainer`) until
/// the first read or write, keeping file I/O and migration checks off the
/// app-launch path. A factory failure degrades to dropped writes and empty
/// reads rather than crashing.
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
```

- [x] **Step 4: Run tests** — `swift test`. Expected: all pass.
- [x] **Step 5: Commit** — `perf(launch): add LazySessionStore to defer container creation`

---

### Task 5: Lazy view models in `AppDelegate`, resolved per tab

**Files:**
- Modify: `App/AppDelegate.swift:11-46` (lazy vars, drop `EmptySessionReader`)
- Modify: `App/FocusFlowApp.swift:7-15`
- Modify: `Features/MenuBar/RootPopoverView.swift`

**Interfaces:**
- Consumes: `LazySessionStore` (Task 4).
- Produces: `RootPopoverView(delegate: AppDelegate, onOpenPreferences: () -> Void)`.

- [x] **Step 1: Make the view models lazy.** In `AppDelegate`, replace the stored `statsVM`/`soundMixerVM`/`sessionStore` with:

```swift
private lazy var sessionStore = LazySessionStore { try SwiftDataSessionStore() }
lazy var statsVM = StatsViewModel(reader: sessionStore)
lazy var soundMixerVM = SoundMixerViewModel(
    engine: AVAmbientAudioEngine(),
    ticker: DispatchSourceTimerTicker())
```

`timerVM` stays eager but takes `sessionRecorder: sessionStore`. Because `sessionStore` is itself lazy and `LazySessionStore.init` touches nothing, no container is built at launch. Delete `EmptySessionReader` — `LazySessionStore` subsumes it. Note: `lazy var` referencing another `lazy var` requires them to be instance-level, so move construction of `timerVM` out of `init` into a `lazy var` too, or keep `timerVM` in `init` and pass a `LazySessionStore` created there.

- [x] **Step 2: Resolve per tab in `RootPopoverView`** so building the popover doesn't force every model:

```swift
struct RootPopoverView: View {
    let delegate: AppDelegate
    var onOpenPreferences: () -> Void = {}
    @State private var tab: PopoverTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .timer: TimerPopoverView(vm: delegate.timerVM, onOpenPreferences: onOpenPreferences)
            case .stats: StatsView(vm: delegate.statsVM)
            case .sounds: SoundMixerView(vm: delegate.soundMixerVM)
            case .settings: TimerPopoverView(vm: delegate.timerVM, onOpenPreferences: onOpenPreferences)
            }
            PopoverTabBar(selection: $tab, onSettings: onOpenPreferences)
                .frame(width: DesignTokens.menuWidth)
        }
        .background(DesignTokens.surface)
    }
}
```

Update `FocusFlowApp` to `RootPopoverView(delegate: appDelegate, onOpenPreferences: { appDelegate.showPreferences() })`.

- [x] **Step 3: Build and launch** — `xcodegen generate && xcodebuild ... build`, then open the app, switch to Stats and Sounds. Expected: BUILD SUCCEEDED, tabs work.
- [x] **Step 4: Commit** — `perf(launch): construct stats and sound view models on first use`

---

### Task 6: `TaskList` domain type

**Files:**
- Create: `Sources/FocusFlowKit/Tasks/TaskList.swift`
- Test: `Tests/FocusFlowKitTests/TaskListTests.swift`

**Interfaces:**
- Produces: `TaskItem(id:title:isDone:completedPomodoros:createdAt:)`; `TaskList(items:activeID:)` with `add(title:createdAt:) -> UUID?`, `rename(_:to:)`, `toggleDone(_:)`, `delete(_:)`, `setActive(_:)`, `move(fromOffsets:toOffset:)`, `creditPomodoro(to:)`, `openItems`, `doneItems`, `activeItem`.

- [x] **Step 1: Write the failing tests** covering every rule in the spec:

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct TaskListTests {
    private func list(_ titles: String...) -> TaskList {
        var l = TaskList()
        for t in titles { _ = l.add(title: t, createdAt: Date(timeIntervalSince1970: 0)) }
        return l
    }

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

    @Test func doneItemsSinkBelowOpenOnes() {
        var l = list("a", "b", "c")
        l.toggleDone(l.items[0].id)
        #expect(l.items.map(\.title) == ["b", "c", "a"])
        #expect(l.openItems.map(\.title) == ["b", "c"])
        #expect(l.doneItems.map(\.title) == ["a"])
    }

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

    @Test func moveReordersWithinOpenItemsOnly() {
        var l = list("a", "b", "c")
        l.toggleDone(l.items[0].id)          // a is done, open == [b, c]
        l.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)   // open == [c, b]
        #expect(l.openItems.map(\.title) == ["c", "b"])
        #expect(l.items.map(\.title) == ["c", "b", "a"])
    }

    @Test func renameTrimsAndIgnoresEmpty() {
        var l = list("a")
        let id = l.items[0].id
        l.rename(id, to: "  b ")
        #expect(l.items[0].title == "b")
        l.rename(id, to: "  ")
        #expect(l.items[0].title == "b")
    }
}
```

- [x] **Step 2: Run and watch fail** — `swift test --filter TaskListTests`. Expected: compile failure, `TaskList` not found.
- [x] **Step 3: Implement `TaskList.swift`.** Keep `items` normalized (open first, done last, stable within group) by re-sorting after each mutation with a stable partition:

```swift
import Foundation

public struct TaskItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public var completedPomodoros: Int
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, isDone: Bool = false,
                completedPomodoros: Int = 0, createdAt: Date) {
        self.id = id; self.title = title; self.isDone = isDone
        self.completedPomodoros = completedPomodoros; self.createdAt = createdAt
    }
}

/// Ordering and active-selection rules for the to-do list. Pure value type —
/// no clock, no storage — so the rules are testable in isolation.
public struct TaskList: Equatable, Sendable {
    public private(set) var items: [TaskItem]
    public private(set) var activeID: UUID?

    public init(items: [TaskItem] = [], activeID: UUID? = nil) {
        self.items = items
        self.activeID = activeID
        normalize()
        if let activeID, !items.contains(where: { $0.id == activeID && !$0.isDone }) {
            self.activeID = nil
        }
    }

    public var openItems: [TaskItem] { items.filter { !$0.isDone } }
    public var doneItems: [TaskItem] { items.filter(\.isDone) }
    public var activeItem: TaskItem? { activeID.flatMap { id in items.first { $0.id == id } } }

    @discardableResult
    public mutating func add(title: String, createdAt: Date) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TaskItem(title: trimmed, createdAt: createdAt)
        items.append(item)
        normalize()
        return item.id
    }

    public mutating func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = index(of: id) else { return }
        items[i].title = trimmed
    }

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

    /// Only an open item can be active; passing nil or a done item clears it.
    public mutating func setActive(_ id: UUID?) {
        guard let id, let i = index(of: id), !items[i].isDone else { activeID = nil; return }
        activeID = id
    }

    /// Offsets index into `openItems`, matching what the list UI offers.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var open = openItems
        open.move(fromOffsets: source, toOffset: destination)
        items = open + doneItems
    }

    public mutating func creditPomodoro(to id: UUID) {
        guard let i = index(of: id) else { return }
        items[i].completedPomodoros += 1
    }

    private func index(of id: UUID) -> Int? { items.firstIndex { $0.id == id } }

    /// Stable partition: open items keep their relative order, done items follow.
    private mutating func normalize() { items = items.filter { !$0.isDone } + items.filter(\.isDone) }
}
```

- [x] **Step 4: Run tests** — `swift test --filter TaskListTests`. Expected: all pass.
- [x] **Step 5: Commit** — `feat(tasks): add TaskList domain type`

---

### Task 7: Task persistence on a shared container

**Files:**
- Create: `Sources/FocusFlowKit/Tasks/TaskStoring.swift`, `Sources/FocusFlowKit/Tasks/TaskEntity.swift`, `Sources/FocusFlowKit/Tasks/SwiftDataTaskStore.swift`, `Sources/FocusFlowKit/Stats/ModelContainerProvider.swift`
- Modify: `Sources/FocusFlowKit/Stats/SessionEntity.swift` (use the shared container)
- Test: `Tests/FocusFlowKitTests/SwiftDataTaskStoreTests.swift`

**Interfaces:**
- Consumes: `TaskList`, `TaskItem` (Task 6).
- Produces: `protocol TaskStoring { func load() -> TaskList; func save(_ list: TaskList) }`; `SwiftDataTaskStore(container:)` and `SwiftDataTaskStore(inMemory:) throws`; `AppModelContainer.make(inMemory: Bool) throws -> ModelContainer` plus `AppModelContainer.shared() throws -> ModelContainer`, which memoizes one on-disk container so both stores share it (`make` stays available for tests, which want a fresh in-memory one each time).

- [x] **Step 1: Write the failing tests:**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct SwiftDataTaskStoreTests {
    @Test func roundTripsItemsOrderAndActiveSelection() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        var list = TaskList()
        let a = list.add(title: "a", createdAt: Date(timeIntervalSince1970: 1))!
        _ = list.add(title: "b", createdAt: Date(timeIntervalSince1970: 2))
        list.creditPomodoro(to: a)
        list.setActive(a)
        store.save(list)

        let loaded = store.load()
        #expect(loaded.items.map(\.title) == ["a", "b"])
        #expect(loaded.activeID == a)
        #expect(loaded.items[0].completedPomodoros == 1)
    }

    @Test func startsEmpty() throws {
        #expect(try SwiftDataTaskStore(inMemory: true).load().items.isEmpty)
    }

    @Test func savePreservesDoneItemsAtTheBottom() throws {
        let store = try SwiftDataTaskStore(inMemory: true)
        var list = TaskList()
        let a = list.add(title: "a", createdAt: Date(timeIntervalSince1970: 1))!
        _ = list.add(title: "b", createdAt: Date(timeIntervalSince1970: 2))
        list.toggleDone(a)
        store.save(list)
        #expect(store.load().items.map(\.title) == ["b", "a"])
    }

    @Test func sessionsAndTasksShareOneContainer() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let tasks = SwiftDataTaskStore(container: container)
        let sessions = SwiftDataSessionStore(container: container)
        var list = TaskList(); _ = list.add(title: "a", createdAt: Date())
        tasks.save(list)
        sessions.record(FocusSessionRecord(startedAt: Date(), duration: 60))
        #expect(tasks.load().items.count == 1)
        #expect(sessions.allSessions().count == 1)
    }
}
```

- [x] **Step 2: Run and watch fail** — `swift test --filter SwiftDataTaskStoreTests`. Expected: compile failure.
- [x] **Step 3: Implement.** `AppModelContainer.make` builds one `ModelContainer(for: SessionEntity.self, TaskEntity.self, configurations:)`. Both stores gain a `init(container:)` alongside the existing convenience `init(inMemory:) throws`. `TaskEntity` carries `id, title, isDone, completedPomodoros, createdAt, sortIndex, isActive`. `save` replaces all rows (the list is tens of items — simplicity beats diffing at this scale), assigning `sortIndex` by position. `load` sorts by `(isDone, sortIndex)`, and if more than one row has `isActive`, the first in sort order wins.
- [x] **Step 4: Point `AppDelegate` at the shared container.** Task 5 wired `LazySessionStore { try SwiftDataSessionStore() }`; now that a shared container exists it becomes `LazySessionStore { try SwiftDataSessionStore(container: AppModelContainer.shared()) }`, so the app opens one container rather than two.
- [x] **Step 5: Run tests** — `swift test`. Expected: all pass, including the existing `SwiftDataSessionStoreTests`.
- [x] **Step 6: Commit** — `feat(tasks): persist tasks in a container shared with sessions`

---

### Task 8: Attribute completed focus sessions to the active task

**Files:**
- Modify: `Sources/FocusFlowKit/Stats/FocusSessionRecord.swift`, `Sources/FocusFlowKit/Stats/SessionEntity.swift`
- Create: `Sources/FocusFlowKit/Tasks/ActiveTaskProviding.swift`
- Modify: `Sources/FocusFlowKit/State/TimerViewModel.swift`
- Test: `Tests/FocusFlowKitTests/TimerViewModelTaskAttributionTests.swift`

**Interfaces:**
- Produces: `FocusSessionRecord.taskID: UUID?` (defaulted `nil` so existing call sites compile unchanged); `protocol ActiveTaskProviding: AnyObject { var activeTaskID: UUID? { get }; func creditFocusSession(to id: UUID) }`; `TimerViewModel.init(..., tasks: ActiveTaskProviding? = nil)`.

- [x] **Step 1: Write the failing tests:**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor final class ActiveTaskSpy: ActiveTaskProviding {
    var activeTaskID: UUID?
    private(set) var credited: [UUID] = []
    func creditFocusSession(to id: UUID) { credited.append(id) }
}

@MainActor
@Suite struct TimerViewModelTaskAttributionTests {
    private func makeVM(tasks: ActiveTaskProviding?, recorder: SessionRecorderSpy,
                        ticker: FakeTicker, clock: FakeClock) -> TimerViewModel {
        TimerViewModel(settings: PomodoroSettings(focusDuration: 60, shortBreakDuration: 30,
                                                  longBreakDuration: 60, longBreakInterval: 4),
                       ticker: ticker, clock: clock,
                       notifications: NotificationSpy(), sound: SoundSpy(),
                       sessionRecorder: recorder, tasks: tasks)
    }

    @Test func stampsAndCreditsTheActiveTask() {
        let spy = ActiveTaskSpy()
        let id = UUID()
        spy.activeTaskID = id
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: spy, recorder: recorder, ticker: ticker, clock: clock)

        vm.start()
        clock.advance(by: 61)
        ticker.fire()

        #expect(recorder.recorded.count == 1)
        #expect(recorder.recorded.first?.taskID == id)
        #expect(spy.credited == [id])
    }

    @Test func recordsNilTaskIdAndCreditsNothingWhenNoActiveTask() {
        let spy = ActiveTaskSpy()          // activeTaskID stays nil
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: spy, recorder: recorder, ticker: ticker, clock: clock)

        vm.start()
        clock.advance(by: 61)
        ticker.fire()

        #expect(recorder.recorded.first?.taskID == nil)
        #expect(spy.credited.isEmpty)
    }

    @Test func worksWithNoTaskProviderAtAll() {
        let recorder = SessionRecorderSpy()
        let ticker = FakeTicker(), clock = FakeClock()
        let vm = makeVM(tasks: nil, recorder: recorder, ticker: ticker, clock: clock)

        vm.start()
        clock.advance(by: 61)
        ticker.fire()

        #expect(recorder.recorded.count == 1)
        #expect(recorder.recorded.first?.taskID == nil)
    }
}
```

- [x] **Step 2: Run and watch fail** — `swift test --filter TimerViewModelTaskAttribution`. Expected: compile failure.
- [x] **Step 3: Implement.** Add `taskID` to `FocusSessionRecord` (last parameter, defaulted `nil`) and to `SessionEntity` as an optional stored property mapped through `asRecord`. In `TimerViewModel.completePhase`, inside the existing `if finished == .focus` branch:

```swift
let taskID = tasks?.activeTaskID
sessionRecorder?.record(
    FocusSessionRecord(startedAt: clock.now.addingTimeInterval(-finishedDuration),
                       duration: finishedDuration, taskID: taskID))
if let taskID { tasks?.creditFocusSession(to: taskID) }
```

- [x] **Step 4: Run tests** — `swift test`. Expected: all pass, existing timer tests unchanged.
- [x] **Step 5: Commit** — `feat(tasks): attribute completed focus sessions to the active task`

---

### Task 9: `TasksViewModel`

**Files:**
- Create: `Sources/FocusFlowKit/Tasks/TasksViewModel.swift`
- Test: `Tests/FocusFlowKitTests/TasksViewModelTests.swift`

**Interfaces:**
- Consumes: `TaskList`, `TaskStoring`, `ActiveTaskProviding`.
- Produces: `TasksViewModel(store: @escaping () throws -> TaskStoring, clock: Clock = SystemClock())` with `items`, `doneItems`, `activeItem`, `add(_:)`, `toggleDone(_:)`, `delete(_:)`, `setActive(_:)`, `move(fromOffsets:toOffset:)`.

- [x] **Step 1: Write the failing tests:**

```swift
@MainActor final class TaskStoreSpy: TaskStoring {
    var stored = TaskList()
    private(set) var saveCount = 0
    private(set) var loadCount = 0
    func load() -> TaskList { loadCount += 1; return stored }
    func save(_ list: TaskList) { saveCount += 1; stored = list }
}

@MainActor
@Suite struct TasksViewModelTests {
    @Test func doesNotTouchTheStoreUntilFirstAccess() {
        var made = 0
        _ = TasksViewModel(store: { made += 1; return TaskStoreSpy() })
        #expect(made == 0)
    }

    @Test func loadsOnceAcrossRepeatedReads() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        _ = vm.items; _ = vm.items; _ = vm.activeTaskID
        #expect(spy.loadCount == 1)
    }

    @Test func writesThroughOnEveryMutation() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        vm.add("write spec")
        #expect(spy.saveCount == 1)
        #expect(spy.stored.items.map(\.title) == ["write spec"])
        vm.setActive(vm.items[0].id)
        #expect(spy.saveCount == 2)
        #expect(spy.stored.activeID == vm.items[0].id)
    }

    @Test func creditingAFocusSessionPersists() {
        let spy = TaskStoreSpy()
        let vm = TasksViewModel(store: { spy })
        vm.add("a")
        let id = vm.items[0].id
        vm.creditFocusSession(to: id)
        #expect(vm.items[0].completedPomodoros == 1)
        #expect(spy.stored.items[0].completedPomodoros == 1)
    }

    @Test func fallsBackToMemoryWhenTheStoreIsUnavailable() {
        struct Boom: Error {}
        let vm = TasksViewModel(store: { throw Boom() })
        vm.add("a")
        #expect(vm.items.map(\.title) == ["a"])
    }
}
```

- [x] **Step 2: Run and watch fail** — `swift test --filter TasksViewModelTests`. Expected: compile failure.
- [x] **Step 3: Implement** — `@MainActor @Observable final class TasksViewModel: ActiveTaskProviding`, holding `private var loaded: TaskList?` and a `list` accessor that loads on first touch (resolving the store factory once, tolerating a throw by leaving `store` nil). Every mutation applies to `list` then calls `store?.save(list)`.
- [x] **Step 4: Run tests** — `swift test`. Expected: all pass.
- [x] **Step 5: Commit** — `feat(tasks): add TasksViewModel with lazy store and write-through`

---

### Task 10: Tasks tab UI

**Files:**
- Create: `Features/Tasks/TasksView.swift`, `Features/Tasks/TaskRow.swift`
- Modify: `Features/MenuBar/PopoverTabBar.swift` (add `.tasks`), `Features/MenuBar/RootPopoverView.swift`, `App/AppDelegate.swift`

**Interfaces:**
- Consumes: `TasksViewModel` (Task 9), `RootPopoverView(delegate:)` (Task 5).

- [x] **Step 1: Add the tab case** — `case tasks` between `.timer` and `.stats` in `PopoverTab`, symbol `checklist`, label `"Tasks"`.
- [x] **Step 2: Build `TaskRow`** — a completion button (`circle` / `checkmark.circle.fill`), the title (struck through and secondary when done), a pomodoro count badge shown only when `completedPomodoros > 0`, and an active indicator dot in `DesignTokens.accent(for: .focus)`. Tapping the row calls `onActivate`. `.contextMenu` offers Delete. Height `DesignTokens.rowMinHeight`.
- [x] **Step 3: Build `TasksView`** — a `TextField` bound to `@State private var draft` that calls `vm.add(draft)` on submit and clears; open rows; a separator and the done rows when non-empty; empty state text "No tasks yet" when the list is empty. Width `DesignTokens.menuWidth`, wrapped in a `ScrollView` with `.frame(maxHeight: 320)`.
- [x] **Step 4: Wire it up** — `AppDelegate` gains `let tasksVM = TasksViewModel(store: { try SwiftDataTaskStore(container: AppModelContainer.shared()) })` constructed in `init` (cheap — its store is lazy), passed to `TimerViewModel(..., tasks: tasksVM)`; `RootPopoverView` renders `case .tasks: TasksView(vm: delegate.tasksVM)`.
- [x] **Step 5: Build and exercise** — `xcodegen generate && xcodebuild ... build`, launch, add two tasks, complete one, activate the other. Expected: BUILD SUCCEEDED and the list behaves.
- [x] **Step 6: Commit** — `feat(tasks): add the Tasks tab`

---

### Task 11: Active-task chip on the timer screen

**Files:**
- Create: `Features/Tasks/ActiveTaskChip.swift`
- Modify: `Features/Timer/TimerPopoverView.swift`, `Features/MenuBar/RootPopoverView.swift`

- [x] **Step 1: Build `ActiveTaskChip`** — takes `vm: TasksViewModel` and `onPick: () -> Void`. Shows the active item's title plus its pomodoro count, or "No task selected" in `DesignTokens.secondaryText` when `activeItem` is nil; tapping calls `onPick`. Background `DesignTokens.surfaceContainerHigh`, corner radius `DesignTokens.radiusControl`. It reads only `TasksViewModel`, so timer ticks don't invalidate it.
- [x] **Step 2: Place it** in `TimerPopoverView` between `controls` and `SessionList`, threading `tasksVM` and an `onPickTask` closure through from `RootPopoverView`, which sets `tab = .tasks`.
- [x] **Step 3: Build and exercise** — activate a task, confirm the chip shows it on the Timer tab and that tapping the chip with no active task jumps to Tasks.
- [x] **Step 4: Commit** — `feat(tasks): show the active task on the timer screen`

---

### Task 12: Verify and measure

- [x] **Step 1: Full kit suite** — `swift test`. Expected: every test passes; record the count.
- [x] **Step 2: App build** — `xcodegen generate && xcodebuild ... build`. Expected: BUILD SUCCEEDED.
- [ ] **Step 3: Measure 1a** — run a focus session with the popover open and `sample FocusFlow 10` before and after the change (compare against the pre-Task-1 commit). Record CPU numbers.
- [ ] **Step 4: Measure 1b** — timestamp from `applicationWillFinishLaunching` to the first `MenuBarLabel` body evaluation, debug build, before and after. Record milliseconds.
- [ ] **Step 5: End-to-end check** — activate a task, run a short focus phase to completion, confirm the count increments and survives a relaunch.
- [x] **Step 6: Commit** — `docs: record task-list and performance-pass results`

## Results (2026-08-03)

**Done and verified:**

- 109 kit tests pass (`swift test`), up from 64. App builds and launches clean — no
  crash reports, nothing in `log show` for the process.
- **1b measured directly.** With the app freshly launched and the popover never opened,
  `lsof` on the process shows no `.store`/`.sqlite` handle: the SwiftData container is not
  opened at launch. Previously `AppDelegate.init` ran `try? SwiftDataSessionStore()`
  unconditionally, so the container was always opened on the launch path.
- **1c proved by test**, which is the more durable check anyway: `allSessions()` runs once
  across repeated refreshes, again after a write, and again after the clock crosses
  midnight.

**Not measured — stated plainly rather than asserted:**

- **1a (per-tick invalidation)** is verified structurally only: `TimerPopoverView` no longer
  reads `displayTime` or `progress` (grep-confirmed), so a tick can only invalidate
  `TimerReadout`. A CPU before/after needs the popover held open, which needs a click on the
  menu-bar item that cannot be driven from here. No CPU numbers are claimed.
- **Launch wall-clock delta** is likewise unmeasured; the container-open evidence above is
  the direct form of the claim, and a millisecond figure would be dominated by dyld noise.
- **End-to-end run** (activate a task, complete a focus phase, confirm the count survives
  relaunch) needs the same UI interaction. The path is covered by unit tests at every seam —
  attribution, credit, write-through, and store round-trip — but has not been exercised
  through the real UI.
