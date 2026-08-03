# FocusFlow — Task List & Performance Pass: Design

**Date:** 2026-08-03
**Status:** Approved (design phase)
**Builds on:** `2026-06-08-focusflow-macos-design.md` (v1 architecture), deferred-features work of 2026-06-20

## Overview

Two changes to the shipped app, delivered as separate commits in this order:

1. **Performance pass** — three targeted fixes to existing code, verifiable in isolation.
2. **Task list** — a to-do list whose items receive credit for completed focus sessions.

Perf lands first so its measurements are not muddied by a new feature arriving at the
same time.

The task list is not a generic checklist bolted onto a Pomodoro app: an item can be made
*active*, and every focus session that completes while it is active is attributed to it.
That attribution is what makes the feature belong here.

## Part 1 — Performance

Three concrete problems in the current code, each with its own verification.

### 1a. Per-tick invalidation covers the whole popover

`TimerPopoverView.body` reads `vm.displayTime` and `vm.progress`. Under `@Observable`,
invalidation is per-view-body, so a body that reads a per-second value re-runs every
second — here that drags the header, the transport controls, and `SessionList` along with
the ring. Adding the active-task chip to that screen would enlarge the same problem.

**Fix:** extract the ring, the `MM:SS` readout, and the phase label into a `TimerReadout`
view. It is then the only body reading per-second state; the rest of the screen reads only
`vm.phase` and `vm.isRunning` and re-runs on phase changes alone.

`MenuBarLabel` legitimately re-renders every second — that is the feature — and is left
alone.

**Verify:** CPU sample of the app with a session running and the popover open, before and
after. Report the numbers.

### 1b. Launch path does avoidable work

`AppDelegate.init` builds, before the menu-bar item can appear:

- the SwiftData `ModelContainer` (file I/O plus a migration check),
- `AVAmbientAudioEngine`,
- two `DispatchSourceTimerTicker`s,
- `StatsViewModel` and `SoundMixerViewModel`.

Only the timer is needed at launch.

**Fix:**

- `StatsViewModel` and `SoundMixerViewModel` (and the audio engine and second ticker they
  own) become `lazy var` on `AppDelegate`, constructed on first visit to their tab.
- `TimerViewModel` requires a `SessionRecording` at init, so it receives a
  `LazySessionStore` façade: a `SessionRecording` + `SessionReading` wrapper holding a
  `() throws -> SwiftDataSessionStore` factory, resolving the real store on first use —
  which is the first completed focus session, minutes after launch. On resolution failure
  it degrades to no-op writes and empty reads, replacing today's `try?`-in-init and the
  `EmptySessionReader` fallback.

**Verify:** signpost or timestamp from `applicationWillFinishLaunching` to the menu-bar
item appearing, debug build, before and after. Report the numbers.

### 1c. Stats re-aggregate the full history on every tab visit

`StatsView.onAppear` calls `vm.refresh()`, which fetches every `SessionEntity`, hydrates
each into a `FocusSessionRecord`, and re-runs the whole aggregation — even when nothing
changed since the last visit. Cost grows without bound as history accumulates.

**Fix:**

- `SessionReading` gains `var revision: Int { get }`. `SwiftDataSessionStore` increments it
  on every successful write. `StatsViewModel.refresh()` returns early when the revision
  matches the one it last aggregated.
- The fetch narrows to the two properties the aggregator reads (`startedAt`, `duration`)
  via `propertiesToFetch`, avoiding full object hydration.

**Verify:** a `SessionReading` spy asserting `allSessions()` is called exactly once across
repeated `refresh()` calls with no writes in between, and again after a write.

### Explicitly not in scope

No change to the ticker interval or timer semantics, no rework of the observation re-arm in
`observeSettings`, no design-system or animation changes. Those are not the problems above.

## Part 2 — Task List

### Domain: `Tasks/TaskList.swift` (FocusFlowKit)

Pure value types, Foundation-only, in the style of `PomodoroEngine`. This is where the
ordering and active-selection rules live, so they are unit-tested without a UI.

```swift
public struct TaskItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public var completedPomodoros: Int
    public let createdAt: Date
}

public struct TaskList: Equatable, Sendable {
    public private(set) var items: [TaskItem]
    public private(set) var activeID: UUID?
}
```

Mutations: `add(title:)`, `rename(_:to:)`, `toggleDone(_:)`, `delete(_:)`, `setActive(_:)`,
`move(from:to:)`, `creditPomodoro(to:)`.

Rules, fixed here so implementation has nothing to invent:

- Open items sort before done items. Within each group, insertion order is preserved, and
  `move` reorders within the open group only.
- Marking the active item done clears `activeID`. Deleting the active item clears
  `activeID`. Un-marking a done item does not restore active status.
- `creditPomodoro(to:)` increments `completedPomodoros`; an id not in the list is ignored
  rather than trapping (the task may have been deleted mid-session).
- `add` trims whitespace and ignores an empty title.
- A done item keeps its `completedPomodoros`.

**No estimates in v1.** A row shows the number of pomodoros actually logged against it, not
"2 of 3". The counter is already there if estimates are wanted later.

### Attribution

`FocusSessionRecord` gains `taskID: UUID?` (defaulting to `nil`, so existing call sites and
tests are unaffected). `TimerViewModel` gains one optional dependency:

```swift
@MainActor public protocol ActiveTaskProviding: AnyObject {
    var activeTaskID: UUID? { get }
    func creditFocusSession(to id: UUID)
}
```

In `completePhase()`, when the finished phase is `.focus`, the view model stamps the record
with `activeTaskID` and, if non-nil, calls `creditFocusSession(to:)`. Nothing else about
the transition sequence changes, and the existing `onPhaseTransition` callback — already
owned by `BreakFlowCoordinator` — is untouched.

Both representations exist on purpose:

- **The session record is the durable event log.** Storing `taskID` there means per-task
  history is available later without a migration.
- **`completedPomodoros` on the item is a cache**, so the list renders without querying
  session history — consistent with the goal of Part 1.

`TimerViewModel` stays headless: it knows the protocol, not the store. Tests use a spy.

### Persistence: `Tasks/TaskEntity.swift`, `Tasks/SwiftDataTaskStore.swift`

- `TaskEntity` (`@Model`) mirrors `TaskItem`, plus a `sortIndex: Int` to persist ordering
  and an `isActive: Bool` (at most one true) to persist the selection across launches.
- `SwiftDataTaskStore` conforms to a `TaskStoring` protocol (`@MainActor`, matching the
  isolation rationale already documented in `SessionRecording.swift`), with `load() ->
  TaskList` and write-through mutations. Writes are best-effort `try?`, as in
  `SwiftDataSessionStore` — persistence failure never crashes the app.
- **Shared `ModelContainer`.** `SwiftDataSessionStore` currently owns a private container.
  A small container provider is extracted so `SessionEntity` and `TaskEntity` share one
  container, rather than opening two over the same store. Both changes — a new entity and a
  new optional property on `SessionEntity` — are additive, which SwiftData's lightweight
  migration handles for the existing on-disk database.

### State: `Tasks/TasksViewModel.swift`

`@MainActor @Observable`, conforming to `ActiveTaskProviding`. Holds the `TaskList` in memory
as the UI's source of truth and writes through to the store on each mutation — loaded once,
not re-fetched per tab visit, the same principle as fix 1c. If the store fails to
initialise, the view model runs on an in-memory list so the tab still works for the session.

**Its store resolves lazily, like `LazySessionStore` in 1b.** The view model is constructed
at launch (the timer needs it for attribution), but it takes a `() throws -> TaskStoring`
factory and performs its initial `load()` on the first access to `items` or `activeTaskID` —
i.e. the first visit to the Tasks tab or the first completed focus session. Constructing it
must not touch the `ModelContainer`, or it would reintroduce exactly the launch-path cost
Part 1 removes. A test asserts the factory is not invoked during construction.

### Presentation

- `PopoverTab` gains a `.tasks` case; tab order becomes timer, tasks, stats, sounds,
  settings, using SF Symbol `checklist`.
- `Features/Tasks/TasksView.swift` — an add field, the open items, a separator, then done
  items. Sized to the existing `DesignTokens.menuWidth` (280pt), scrolling when it
  overflows.
- `Features/Tasks/TaskRow.swift` — completion checkbox, title, pomodoro count, and an
  active indicator; tapping the row sets it active; a context menu offers delete.
- `Features/Tasks/ActiveTaskChip.swift` — on the timer screen below the transport controls,
  showing the active item's title and count, or a "No task selected" affordance that
  switches to the Tasks tab. It reads only `TasksViewModel`, so per-second timer ticks do
  not invalidate it (see 1a).
- Styling uses existing `DesignTokens` — no new colors or type ramp.

`AppDelegate` owns `TasksViewModel` eagerly (it is cheap and the timer needs it for
attribution at init) and passes it to `RootPopoverView` alongside the existing view models.

## Data Flow

```
User taps a task row ─► TasksViewModel.setActive ─► TaskList mutation ─► SwiftDataTaskStore

Focus phase completes
  └─ TimerViewModel.completePhase
       ├─ reads tasks.activeTaskID       ─► stamps FocusSessionRecord.taskID
       ├─ sessionRecorder.record(...)    ─► LazySessionStore ─► SwiftDataSessionStore (revision++)
       └─ tasks.creditFocusSession(to:)  ─► TaskList.creditPomodoro ─► SwiftDataTaskStore

Stats tab appears ─► StatsViewModel.refresh ─► early-return unless revision changed
```

## Error Handling

Consistent with the existing posture: persistence is best-effort and never fatal. A failed
container or store degrades to in-memory behaviour (tasks) or empty reads and dropped
writes (sessions), and the app keeps running. No user-facing error surface is added.

## Testing

Kit tests (Swift Testing, run with `swift test`):

- `TaskList` — add/trim/ignore-empty, toggle done and its sink-to-bottom ordering, delete,
  active selection and the three clearing rules, `move` within open items, `creditPomodoro`
  including the unknown-id no-op.
- `TasksViewModel` — write-through to a fake store on each mutation; load restores order and
  active selection; in-memory fallback when the store is unavailable.
- Attribution — a `TimerViewModel` focus completion records a `taskID` matching the active
  item and calls `creditFocusSession` exactly once; with no active task the record's
  `taskID` is `nil` and no credit fires.
- Stats caching — a spy proves `allSessions()` runs once across repeated refreshes and again
  after a write bumps the revision.
- Lazy store — the session-store factory is not invoked during `LazySessionStore`
  construction, only on first record or read.

App target: `xcodegen generate` then `xcodebuild -project FocusFlow.xcodeproj -scheme
FocusFlow -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`, then launch and
exercise the Tasks tab and a completed focus session manually.

Performance claims are reported with the before/after measurements described in Part 1, not
with adjectives.

## File Layout Delta

```
Sources/FocusFlowKit/
  Tasks/            TaskList.swift, TaskEntity.swift, SwiftDataTaskStore.swift,
                    TasksViewModel.swift, TaskStoring.swift
  Stats/            + LazySessionStore.swift, revision on SessionReading,
                    taskID on FocusSessionRecord/SessionEntity, shared container provider
  State/            TimerViewModel.swift (attribution)
Features/
  Tasks/            TasksView.swift, TaskRow.swift, ActiveTaskChip.swift
  Timer/            TimerPopoverView.swift (split out TimerReadout.swift)
  MenuBar/          PopoverTabBar.swift (+ .tasks case)
App/                AppDelegate.swift (lazy view models, TasksViewModel)
```
