# FocusFlow Deferred Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the four deferred FocusFlow features — Activity Stats, Ambient Sounds, Breathwork, and Relaxation/Break flow — onto the shipped v1 menu-bar MVP, in four independently shippable phases.

**Architecture:** Each feature follows the established split — pure, fully-tested logic in the `FocusFlowKit` SPM package (`Domain/` value types, `Services/` protocols, `State/` `@Observable` view models), and thin SwiftUI views plus concrete side-effecting services in the app target. Persistence uses SwiftData; ambient audio uses AVFoundation behind a protocol; all countdowns reuse the existing `Clock` + `TimerTicker` wall-clock-anchoring pattern. Break states use the existing `Serene Interval` design system; popover surfaces use `Ventura Focus`.

**Tech Stack:** Swift / SwiftUI, SwiftData, AVFoundation, AppKit (`NSWindow`/`NSHostingView`), Swift Testing, XcodeGen.

## Global Constraints

- Deployment target: **macOS 26.0** (set in `project.yml`; do not lower).
- `FocusFlowKit/Domain/` stays **Foundation-only** — no AppKit/SwiftUI/SwiftData imports in `Domain/`. SwiftData lives in a new `Stats/` group, audio protocols in `Services/`.
- Package language mode is **Swift 5** (`swiftLanguageMode(.v5)`); match existing style.
- Tests use the **Swift Testing** framework (`@Suite` / `@Test` / `#expect`), live in `Tests/FocusFlowKitTests/`, and share fakes in `Tests/FocusFlowKitTests/Support/Fakes.swift`.
- View models are `@MainActor @Observable final class`; dependencies are injected via protocols and `@ObservationIgnored`.
- Countdowns **anchor to an absolute end-`Date`** and recompute remaining from `Clock.now` each tick — never decrement a counter.
- Everything must stay **App-Sandbox-safe** (the App Store path must remain open).
- Kit test command: `swift test`. App build: `xcodegen generate && xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
- App-target source dirs (`App`, `Features`, `Services`, `DesignSystem`) are folder-referenced in `project.yml`, so new files inside them need no `project.yml` edit. New top-level dirs or bundled resources **do** require a `project.yml` edit + `xcodegen generate`.
- Commit after every task with a conventional-commit message.

---

## File Structure

**Phase 1 — Stats**
- Create `Sources/FocusFlowKit/Stats/FocusSessionRecord.swift` — pure value type for a completed focus session.
- Create `Sources/FocusFlowKit/Stats/StatsAggregator.swift` — pure aggregation (totals, streaks, buckets).
- Create `Sources/FocusFlowKit/Stats/SessionRecording.swift` — `SessionRecording` + `SessionReading` protocols.
- Create `Sources/FocusFlowKit/Stats/SessionEntity.swift` — SwiftData `@Model` + `SwiftDataSessionStore`.
- Create `Sources/FocusFlowKit/State/StatsViewModel.swift` — formatted stats for the view.
- Modify `Sources/FocusFlowKit/State/TimerViewModel.swift` — record completed focus sessions.
- Create `Features/Stats/StatsView.swift`, `Features/Stats/StatCard.swift`, `Features/MenuBar/PopoverTabBar.swift`, `Features/MenuBar/RootPopoverView.swift`.
- Modify `App/AppDelegate.swift`, `App/FocusFlowApp.swift` — build the store, host the tab container.

**Phase 2 — Ambient Sounds**
- Create `Sources/FocusFlowKit/Sound/AmbientSound.swift` — sound catalog value type.
- Create `Sources/FocusFlowKit/Sound/AmbientAudioEngine.swift` — `AmbientAudioEngine` protocol.
- Create `Sources/FocusFlowKit/State/SoundMixerViewModel.swift` — layers, volumes, sleep timer.
- Create `Services/AVAmbientAudioEngine.swift` — AVFoundation impl.
- Create `Features/Sound/SoundMixerView.swift`, `Features/Sound/SoundTile.swift`.
- Modify `App/AppDelegate.swift`, `Features/MenuBar/PopoverTabBar.swift`.

**Phase 3 — Breathwork**
- Create `Sources/FocusFlowKit/Breathwork/BreathingPattern.swift` — patterns + phase kinds.
- Create `Sources/FocusFlowKit/Breathwork/BreathingSession.swift` — pure clock-driven state machine.
- Create `Sources/FocusFlowKit/State/BreathingViewModel.swift`.
- Create `DesignSystem/SereneTokens.swift` — sage/misty-blue Serene Interval tokens.
- Create `Features/Breathwork/TechniqueChooserView.swift`, `Features/Breathwork/BreathingSessionView.swift`.

**Phase 4 — Relaxation / Break flow**
- Create `Sources/FocusFlowKit/Breathwork/BreakPrompt.swift` — `BreakPromptKind` + decision helper.
- Create `Features/Relaxation/BreakStartView.swift`, `Features/Relaxation/BreakCompleteView.swift`.
- Create `App/BreakFlowCoordinator.swift` — full-screen window + phase-transition wiring.
- Modify `Sources/FocusFlowKit/State/TimerViewModel.swift` — expose a phase-transition callback.
- Modify `App/AppDelegate.swift`.

---

# Phase 1 — Activity Stats

Records each completed focus session to SwiftData and surfaces totals, streaks, and a 7-day breakdown in a new Stats tab. Independently shippable.

### Task 1.1: `FocusSessionRecord` value type

**Files:**
- Create: `Sources/FocusFlowKit/Stats/FocusSessionRecord.swift`
- Test: `Tests/FocusFlowKitTests/FocusSessionRecordTests.swift`

**Interfaces:**
- Produces: `public struct FocusSessionRecord { public let id: UUID; public let startedAt: Date; public let duration: TimeInterval; public init(id:startedAt:duration:) }`

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct FocusSessionRecordTests {
    @Test func storesItsFields() {
        let start = Date(timeIntervalSince1970: 1_000)
        let r = FocusSessionRecord(id: UUID(), startedAt: start, duration: 1_500)
        #expect(r.startedAt == start)
        #expect(r.duration == 1_500)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FocusSessionRecordTests`
Expected: FAIL — `cannot find 'FocusSessionRecord' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// A single completed focus session. Pure value type — the unit the stats
/// aggregator and the SwiftData store both speak in.
public struct FocusSessionRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let duration: TimeInterval

    public init(id: UUID = UUID(), startedAt: Date, duration: TimeInterval) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FocusSessionRecordTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/Stats/FocusSessionRecord.swift Tests/FocusFlowKitTests/FocusSessionRecordTests.swift
git commit -m "feat(stats): add FocusSessionRecord value type"
```

### Task 1.2: `StatsAggregator` (totals, streak, buckets)

**Files:**
- Create: `Sources/FocusFlowKit/Stats/StatsAggregator.swift`
- Test: `Tests/FocusFlowKitTests/StatsAggregatorTests.swift`

**Interfaces:**
- Consumes: `FocusSessionRecord` (Task 1.1).
- Produces:
  - `public struct DailyBucket: Equatable, Sendable { public let date: Date; public let sessionCount: Int; public let totalFocus: TimeInterval }`
  - `public struct StatsSummary: Equatable, Sendable { public let totalFocus: TimeInterval; public let dailyAverageSessions: Double; public let currentStreakDays: Int; public let bestStreakDays: Int; public let last7Days: [DailyBucket] }`
  - `public enum StatsAggregator { public static func summarize(_ sessions: [FocusSessionRecord], now: Date, calendar: Calendar = .current) -> StatsSummary }`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct StatsAggregatorTests {
    // Fixed calendar in UTC so day-bucketing is deterministic.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        DateComponents(calendar: cal, year: y, month: m, day: d, hour: hour).date!
    }

    @Test func emptyInputYieldsZeroes() {
        let s = StatsAggregator.summarize([], now: day(2026, 6, 20), calendar: cal)
        #expect(s.totalFocus == 0)
        #expect(s.currentStreakDays == 0)
        #expect(s.bestStreakDays == 0)
        #expect(s.last7Days.count == 7)
        #expect(s.last7Days.allSatisfy { $0.sessionCount == 0 })
    }

    @Test func totalsSumAllSessions() {
        let sessions = [
            FocusSessionRecord(startedAt: day(2026, 6, 20), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 20), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 19), duration: 600),
        ]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.totalFocus == 3_600)
    }

    @Test func last7DaysIsOldestToNewestAndBucketsByDay() {
        let sessions = [
            FocusSessionRecord(startedAt: day(2026, 6, 20, hour: 9), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 20, hour: 17), duration: 1_500),
            FocusSessionRecord(startedAt: day(2026, 6, 18), duration: 1_500),
        ]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.last7Days.count == 7)
        #expect(s.last7Days.last?.sessionCount == 2)        // today
        #expect(s.last7Days.last?.totalFocus == 3_000)
        #expect(cal.isDate(s.last7Days.last!.date, inSameDayAs: day(2026, 6, 20)))
    }

    @Test func currentStreakCountsConsecutiveDaysEndingToday() {
        let sessions = [
            FocusSessionRecord(startedAt: day(2026, 6, 20), duration: 1),
            FocusSessionRecord(startedAt: day(2026, 6, 19), duration: 1),
            FocusSessionRecord(startedAt: day(2026, 6, 18), duration: 1),
            // gap on the 17th
            FocusSessionRecord(startedAt: day(2026, 6, 16), duration: 1),
        ]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.currentStreakDays == 3)
        #expect(s.bestStreakDays == 3)
    }

    @Test func currentStreakIsZeroWhenNoSessionToday() {
        let sessions = [FocusSessionRecord(startedAt: day(2026, 6, 18), duration: 1)]
        let s = StatsAggregator.summarize(sessions, now: day(2026, 6, 20), calendar: cal)
        #expect(s.currentStreakDays == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter StatsAggregatorTests`
Expected: FAIL — `cannot find 'StatsAggregator' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public struct DailyBucket: Equatable, Sendable {
    public let date: Date          // start-of-day
    public let sessionCount: Int
    public let totalFocus: TimeInterval
    public init(date: Date, sessionCount: Int, totalFocus: TimeInterval) {
        self.date = date; self.sessionCount = sessionCount; self.totalFocus = totalFocus
    }
}

public struct StatsSummary: Equatable, Sendable {
    public let totalFocus: TimeInterval
    public let dailyAverageSessions: Double
    public let currentStreakDays: Int
    public let bestStreakDays: Int
    public let last7Days: [DailyBucket]   // oldest -> newest, always 7 entries
}

/// Pure aggregation over completed focus sessions. No clock of its own — the
/// caller passes `now` so results are deterministic and testable.
public enum StatsAggregator {
    public static func summarize(
        _ sessions: [FocusSessionRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> StatsSummary {
        let totalFocus = sessions.reduce(0) { $0 + $1.duration }

        // Group sessions by start-of-day.
        var byDay: [Date: (count: Int, focus: TimeInterval)] = [:]
        for s in sessions {
            let key = calendar.startOfDay(for: s.startedAt)
            let cur = byDay[key] ?? (0, 0)
            byDay[key] = (cur.count + 1, cur.focus + s.duration)
        }

        // last 7 days, oldest -> newest, ending today.
        let today = calendar.startOfDay(for: now)
        var last7: [DailyBucket] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let agg = byDay[date] ?? (0, 0)
            last7.append(DailyBucket(date: date, sessionCount: agg.count, totalFocus: agg.focus))
        }

        let activeDays = byDay.count
        let dailyAverageSessions = activeDays == 0 ? 0 : Double(sessions.count) / Double(activeDays)

        let (current, best) = streaks(activeDays: Set(byDay.keys), today: today, calendar: calendar)

        return StatsSummary(
            totalFocus: totalFocus,
            dailyAverageSessions: dailyAverageSessions,
            currentStreakDays: current,
            bestStreakDays: best,
            last7Days: last7
        )
    }

    private static func streaks(activeDays: Set<Date>, today: Date, calendar: Calendar) -> (current: Int, best: Int) {
        guard !activeDays.isEmpty else { return (0, 0) }
        let sorted = activeDays.sorted()

        // Best streak: longest run of consecutive days anywhere.
        var best = 1, run = 1
        for i in 1..<max(sorted.count, 1) where sorted.count > 1 {
            let prev = sorted[i - 1], cur = sorted[i]
            if calendar.date(byAdding: .day, value: 1, to: prev).map({ calendar.isDate($0, inSameDayAs: cur) }) == true {
                run += 1; best = max(best, run)
            } else { run = 1 }
        }
        if sorted.count == 1 { best = 1 }

        // Current streak: consecutive days counting back from today.
        var current = 0
        var cursor = today
        while activeDays.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, best)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter StatsAggregatorTests`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/Stats/StatsAggregator.swift Tests/FocusFlowKitTests/StatsAggregatorTests.swift
git commit -m "feat(stats): add pure StatsAggregator (totals, streaks, 7-day buckets)"
```

### Task 1.3: Session store protocols + SwiftData implementation

**Files:**
- Create: `Sources/FocusFlowKit/Stats/SessionRecording.swift`
- Create: `Sources/FocusFlowKit/Stats/SessionEntity.swift`
- Test: `Tests/FocusFlowKitTests/SwiftDataSessionStoreTests.swift`

**Interfaces:**
- Consumes: `FocusSessionRecord` (Task 1.1).
- Produces:
  - `public protocol SessionRecording: AnyObject { func record(_ session: FocusSessionRecord) }`
  - `public protocol SessionReading: AnyObject { func allSessions() -> [FocusSessionRecord] }`
  - `@MainActor public final class SwiftDataSessionStore: SessionRecording, SessionReading` with `public init(inMemory: Bool = false) throws`.

- [ ] **Step 1: Write `SessionRecording.swift` (protocols only)**

```swift
import Foundation

/// Persists completed focus sessions. The view model depends only on this,
/// so it stays headless and testable with a spy.
public protocol SessionRecording: AnyObject {
    func record(_ session: FocusSessionRecord)
}

/// Reads back persisted sessions for the stats view.
public protocol SessionReading: AnyObject {
    func allSessions() -> [FocusSessionRecord]
}
```

- [ ] **Step 2: Write the failing test**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct SwiftDataSessionStoreTests {
    @Test func recordsAndReadsBackSessions() throws {
        let store = try SwiftDataSessionStore(inMemory: true)
        let start = Date(timeIntervalSince1970: 5_000)
        store.record(FocusSessionRecord(startedAt: start, duration: 1_500))
        store.record(FocusSessionRecord(startedAt: start.addingTimeInterval(3_600), duration: 600))

        let all = store.allSessions()
        #expect(all.count == 2)
        #expect(all.contains { $0.duration == 1_500 })
        #expect(all.contains { $0.duration == 600 })
    }

    @Test func startsEmpty() throws {
        let store = try SwiftDataSessionStore(inMemory: true)
        #expect(store.allSessions().isEmpty)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter SwiftDataSessionStoreTests`
Expected: FAIL — `cannot find 'SwiftDataSessionStore' in scope`.

- [ ] **Step 4: Write `SessionEntity.swift`**

```swift
import Foundation
import SwiftData

/// SwiftData persistence record for a completed focus session. Kept out of
/// `Domain/` so the domain layer stays Foundation-only.
@Model
public final class SessionEntity {
    public var id: UUID
    public var startedAt: Date
    public var duration: TimeInterval

    public init(id: UUID, startedAt: Date, duration: TimeInterval) {
        self.id = id; self.startedAt = startedAt; self.duration = duration
    }

    var asRecord: FocusSessionRecord {
        FocusSessionRecord(id: id, startedAt: startedAt, duration: duration)
    }
}

@MainActor
public final class SwiftDataSessionStore: SessionRecording, SessionReading {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: SessionEntity.self, configurations: config)
    }

    public func record(_ session: FocusSessionRecord) {
        context.insert(SessionEntity(id: session.id, startedAt: session.startedAt, duration: session.duration))
        try? context.save()   // best-effort; never crash on persistence failure
    }

    public func allSessions() -> [FocusSessionRecord] {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.asRecord)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter SwiftDataSessionStoreTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/FocusFlowKit/Stats/SessionRecording.swift Sources/FocusFlowKit/Stats/SessionEntity.swift Tests/FocusFlowKitTests/SwiftDataSessionStoreTests.swift
git commit -m "feat(stats): add SwiftData session store behind recording/reading protocols"
```

### Task 1.4: Record completed focus sessions from `TimerViewModel`

**Files:**
- Modify: `Sources/FocusFlowKit/State/TimerViewModel.swift`
- Modify: `Tests/FocusFlowKitTests/Support/Fakes.swift` (add `SessionRecorderSpy`)
- Test: `Tests/FocusFlowKitTests/TimerViewModelStatsTests.swift`

**Interfaces:**
- Consumes: `SessionRecording`, `FocusSessionRecord`.
- Produces: `TimerViewModel.init(... sessionRecorder: SessionRecording? = nil)`; on focus-phase completion the VM calls `sessionRecorder?.record(_:)` with `startedAt = clock.now - phaseDuration` and `duration = phaseDuration`.

- [ ] **Step 1: Add the spy to `Fakes.swift`**

```swift
/// Records sessions handed to it by the view model.
final class SessionRecorderSpy: SessionRecording {
    private(set) var recorded: [FocusSessionRecord] = []
    func record(_ session: FocusSessionRecord) { recorded.append(session) }
}
```

- [ ] **Step 2: Write the failing test**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct TimerViewModelStatsTests {
    private func makeVM(_ recorder: SessionRecorderSpy, clock: FakeClock, ticker: FakeTicker)
        -> TimerViewModel {
        TimerViewModel(
            settings: PomodoroSettings(focusDuration: 60, shortBreakDuration: 30,
                                       longBreakDuration: 45, longBreakInterval: 4),
            ticker: ticker, clock: clock,
            notifications: NotificationSpy(), sound: SoundSpy(),
            sessionRecorder: recorder)
    }

    @Test func recordsOneFocusSessionWhenFocusCompletes() {
        let recorder = SessionRecorderSpy(); let clock = FakeClock(); let ticker = FakeTicker()
        let vm = makeVM(recorder, clock: clock, ticker: ticker)
        vm.start()
        clock.advance(by: 60); vm.tick()      // focus elapses
        #expect(recorder.recorded.count == 1)
        #expect(recorder.recorded.first?.duration == 60)
    }

    @Test func doesNotRecordWhenBreakCompletes() {
        let recorder = SessionRecorderSpy(); let clock = FakeClock(); let ticker = FakeTicker()
        let vm = makeVM(recorder, clock: clock, ticker: ticker)
        vm.start(); clock.advance(by: 60); vm.tick()   // focus -> short break
        vm.start(); clock.advance(by: 30); vm.tick()   // break elapses
        #expect(recorder.recorded.count == 1)          // still just the focus session
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter TimerViewModelStatsTests`
Expected: FAIL — extra argument `sessionRecorder` in call.

- [ ] **Step 4: Modify `TimerViewModel`**

Add the stored dependency (next to the other `@ObservationIgnored` services):

```swift
    @ObservationIgnored private let sessionRecorder: SessionRecording?
```

Add the parameter to `init` (default `nil` keeps existing call sites and tests compiling) and assign it:

```swift
    public init(
        settings: PomodoroSettings = .default,
        ticker: TimerTicker,
        clock: Clock = SystemClock(),
        notifications: NotificationScheduling,
        sound: SoundPlaying,
        sessionRecorder: SessionRecording? = nil
    ) {
        // ...existing assignments...
        self.sessionRecorder = sessionRecorder
        // ...remaining existing assignments...
    }
```

Replace `completePhase()` so a finished focus phase is recorded:

```swift
    private func completePhase() {
        stopTimer()
        let finished = engine.currentPhase
        let finishedDuration = phaseDuration
        sound.playCompletionChime()
        if finished == .focus {
            sessionRecorder?.record(
                FocusSessionRecord(
                    startedAt: clock.now.addingTimeInterval(-finishedDuration),
                    duration: finishedDuration))
        }
        engine.complete()
        notifications.notifyPhaseComplete(finished: finished, next: engine.currentPhase)
        loadCurrentPhase()
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter TimerViewModelStatsTests`
Expected: PASS. Then `swift test` — all prior tests still green.

- [ ] **Step 6: Commit**

```bash
git add Sources/FocusFlowKit/State/TimerViewModel.swift Tests/FocusFlowKitTests/Support/Fakes.swift Tests/FocusFlowKitTests/TimerViewModelStatsTests.swift
git commit -m "feat(stats): record completed focus sessions from TimerViewModel"
```

### Task 1.5: `StatsViewModel`

**Files:**
- Create: `Sources/FocusFlowKit/State/StatsViewModel.swift`
- Test: `Tests/FocusFlowKitTests/StatsViewModelTests.swift`

**Interfaces:**
- Consumes: `SessionReading`, `StatsAggregator`, `Clock`.
- Produces: `@MainActor @Observable final class StatsViewModel` with `init(reader: SessionReading, clock: Clock = SystemClock(), calendar: Calendar = .current)`, `var isEmpty: Bool`, `func refresh()`, and formatted strings `totalFocusText`, `dailyAverageText`, `currentStreakText`, plus `summary: StatsSummary`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct StatsViewModelTests {
    final class StubReader: SessionReading {
        var sessions: [FocusSessionRecord] = []
        func allSessions() -> [FocusSessionRecord] { sessions }
    }
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func isEmptyWhenNoSessions() {
        let vm = StatsViewModel(reader: StubReader(), clock: FakeClock(), calendar: cal)
        vm.refresh()
        #expect(vm.isEmpty)
    }

    @Test func formatsTotalsAfterRefresh() {
        let reader = StubReader()
        let now = DateComponents(calendar: cal, year: 2026, month: 6, day: 20, hour: 12).date!
        reader.sessions = [FocusSessionRecord(startedAt: now, duration: 90 * 60)]   // 1h30m
        let clock = FakeClock(now)
        let vm = StatsViewModel(reader: reader, clock: clock, calendar: cal)
        vm.refresh()
        #expect(!vm.isEmpty)
        #expect(vm.totalFocusText == "1h 30m")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter StatsViewModelTests`
Expected: FAIL — `cannot find 'StatsViewModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class StatsViewModel {
    public private(set) var summary: StatsSummary
    public private(set) var isEmpty: Bool

    @ObservationIgnored private let reader: SessionReading
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let calendar: Calendar

    public init(reader: SessionReading, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        self.reader = reader; self.clock = clock; self.calendar = calendar
        self.summary = StatsAggregator.summarize([], now: clock.now, calendar: calendar)
        self.isEmpty = true
    }

    public func refresh() {
        let sessions = reader.allSessions()
        summary = StatsAggregator.summarize(sessions, now: clock.now, calendar: calendar)
        isEmpty = sessions.isEmpty
    }

    public var totalFocusText: String {
        let mins = Int(summary.totalFocus) / 60
        return "\(mins / 60)h \(mins % 60)m"
    }
    public var dailyAverageText: String { String(format: "%.1f", summary.dailyAverageSessions) }
    public var currentStreakText: String { "\(summary.currentStreakDays)" }
    public var bestStreakText: String { "\(summary.bestStreakDays)" }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter StatsViewModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/State/StatsViewModel.swift Tests/FocusFlowKitTests/StatsViewModelTests.swift
git commit -m "feat(stats): add StatsViewModel with formatted summary"
```

### Task 1.6: Stats UI — `StatCard` + `StatsView`

**Files:**
- Create: `Features/Stats/StatCard.swift`
- Create: `Features/Stats/StatsView.swift`

**Interfaces:**
- Consumes: `StatsViewModel` (Task 1.5), `DesignTokens`.
- Produces: `StatsView(vm: StatsViewModel)` rendering the empty state when `vm.isEmpty`, else summary cards + a 7-day bar row.

- [ ] **Step 1: Implement `StatCard.swift`** (matches the generated Stats screens)

```swift
import SwiftUI

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            Text(value).font(DesignTokens.headlineMd)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.stackTight)
        .background(DesignTokens.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Implement `StatsView.swift`**

```swift
import SwiftUI
import FocusFlowKit

struct StatsView: View {
    let vm: StatsViewModel

    var body: some View {
        Group { if vm.isEmpty { emptyState } else { content } }
            .frame(width: DesignTokens.menuWidth)
            .background(DesignTokens.surface)
            .foregroundStyle(DesignTokens.onSurface)
            .onAppear { vm.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.stackTight) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle).foregroundStyle(DesignTokens.secondaryText)
            Text("No sessions yet").font(DesignTokens.headlineMd)
            Text("Complete your first focus session to start tracking your streak and daily totals.")
                .font(DesignTokens.bodySm).multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(DesignTokens.containerPadding)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.elementGap) {
            HStack(spacing: DesignTokens.stackTight) {
                StatCard(label: "Total Focus", value: vm.totalFocusText)
                StatCard(label: "Daily Avg", value: vm.dailyAverageText)
                StatCard(label: "Streak", value: vm.currentStreakText)
            }
            Text("LAST 7 DAYS").font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            barChart
        }
        .padding(DesignTokens.containerPadding)
    }

    private var barChart: some View {
        let maxFocus = max(1, vm.summary.last7Days.map(\.totalFocus).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(vm.summary.last7Days.enumerated()), id: \.offset) { _, bucket in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bucket.sessionCount > 0 ? DesignTokens.accent(for: .focus) : DesignTokens.surfaceContainerHigh)
                    .frame(height: 8 + 64 * (bucket.totalFocus / maxFocus))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodegen generate && xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`. (If `DesignTokens.bodySm` does not exist, add it to `DesignSystem/DesignTokens.swift` mirroring `labelCaps`, then rebuild.)

- [ ] **Step 4: Commit**

```bash
git add Features/Stats DesignSystem/DesignTokens.swift
git commit -m "feat(stats): add StatsView with empty state and 7-day chart"
```

### Task 1.7: Popover tab bar + root container, wired into the app

**Files:**
- Create: `Features/MenuBar/PopoverTabBar.swift`
- Create: `Features/MenuBar/RootPopoverView.swift`
- Modify: `App/AppDelegate.swift`
- Modify: `App/FocusFlowApp.swift`

**Interfaces:**
- Consumes: `TimerViewModel`, `StatsViewModel`, `TimerPopoverView`, `StatsView`.
- Produces: `RootPopoverView(timerVM:statsVM:onOpenPreferences:)` with a bottom `PopoverTabBar` switching Timer / Stats; `AppDelegate.statsVM`, `AppDelegate.sessionStore`.

- [ ] **Step 1: Implement `PopoverTabBar.swift`**

```swift
import SwiftUI

enum PopoverTab: CaseIterable { case timer, stats, settings
    var symbol: String { switch self { case .timer: "timer"; case .stats: "chart.bar.fill"; case .settings: "gearshape.fill" } }
    var label: String { switch self { case .timer: "Timer"; case .stats: "Stats"; case .settings: "Settings" } }
}

struct PopoverTabBar: View {
    @Binding var selection: PopoverTab
    var onSettings: () -> Void
    var body: some View {
        HStack {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                Button {
                    if tab == .settings { onSettings() } else { selection = tab }
                } label: {
                    Image(systemName: tab.symbol)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(tab == selection ? DesignTokens.accent(for: .focus) : DesignTokens.secondaryText)
                        .accessibilityLabel(tab.label)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignTokens.stackTight)
        .background(DesignTokens.surfaceContainerHigh)
    }
}
```

- [ ] **Step 2: Implement `RootPopoverView.swift`**

```swift
import SwiftUI
import FocusFlowKit

struct RootPopoverView: View {
    let timerVM: TimerViewModel
    let statsVM: StatsViewModel
    var onOpenPreferences: () -> Void = {}
    @State private var tab: PopoverTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .timer: TimerPopoverView(vm: timerVM, onOpenPreferences: onOpenPreferences)
            case .stats: StatsView(vm: statsVM)
            case .settings: TimerPopoverView(vm: timerVM, onOpenPreferences: onOpenPreferences)
            }
            PopoverTabBar(selection: $tab, onSettings: onOpenPreferences)
                .frame(width: DesignTokens.menuWidth)
        }
        .background(DesignTokens.surface)
    }
}
```

- [ ] **Step 3: Add the store + stats VM to `AppDelegate`**

Add stored properties and build them in `init` (after `settings` is created):

```swift
    let statsVM: StatsViewModel
    private let sessionStore: SwiftDataSessionStore?
```
```swift
        // in init, after settings/notifications/sound are set up:
        let store = try? SwiftDataSessionStore()
        self.sessionStore = store
        self.statsVM = StatsViewModel(reader: store ?? EmptySessionReader())
```
Pass the recorder into the timer VM by adding `sessionRecorder: store` to the existing `TimerViewModel(...)` call. Add a tiny fallback reader at the bottom of the file (covers the rare store-init failure, so the UI degrades to empty rather than crashing):

```swift
private final class EmptySessionReader: SessionReading {
    func allSessions() -> [FocusSessionRecord] { [] }
}
```

- [ ] **Step 4: Swap the popover root in `FocusFlowApp.swift`**

```swift
        MenuBarExtra {
            RootPopoverView(
                timerVM: appDelegate.timerVM,
                statsVM: appDelegate.statsVM,
                onOpenPreferences: { appDelegate.showPreferences() })
        } label: {
            MenuBarLabel(vm: appDelegate.timerVM)
        }
        .menuBarExtraStyle(.window)
```

- [ ] **Step 5: Build and run**

Run: `xcodegen generate && xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`. Then `open ~/Library/Developer/Xcode/DerivedData/FocusFlow-*/Build/Products/Debug/FocusFlow.app`, click the menu-bar icon, switch to the Stats tab — empty state shows; after completing a focus session it shows totals. Quit with `pkill -f FocusFlow.app`.

- [ ] **Step 6: Commit**

```bash
git add Features/MenuBar App/AppDelegate.swift App/FocusFlowApp.swift
git commit -m "feat(stats): add popover tab bar and wire Stats into the app"
```

**Phase 1 checkpoint:** `swift test` all green; Stats tab works end-to-end. Tag optional: `git tag v1.1-stats`.

---

# Phase 2 — Ambient Sounds

A looping ambient-sound mixer (per-sound volume + enable) with a sleep timer, behind an audio protocol so the mixer logic is unit-tested. Independently shippable.

### Task 2.1: `AmbientSound` catalog

**Files:**
- Create: `Sources/FocusFlowKit/Sound/AmbientSound.swift`
- Test: `Tests/FocusFlowKitTests/AmbientSoundTests.swift`

**Interfaces:**
- Produces: `public struct AmbientSound: Identifiable, Equatable, Sendable { public let id: String; public let name: String; public let symbol: String }` and `public extension AmbientSound { static let all: [AmbientSound] }` (rain, forest, waves, whiteNoise).

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import FocusFlowKit

@Suite struct AmbientSoundTests {
    @Test func catalogHasFourUniqueSounds() {
        let all = AmbientSound.all
        #expect(all.count == 4)
        #expect(Set(all.map(\.id)).count == 4)
        #expect(all.contains { $0.id == "rain" })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AmbientSoundTests` — Expected: FAIL (not in scope).

- [ ] **Step 3: Write implementation**

```swift
public struct AmbientSound: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String      // SF Symbol name
    public init(id: String, name: String, symbol: String) {
        self.id = id; self.name = name; self.symbol = symbol
    }
}

public extension AmbientSound {
    static let all: [AmbientSound] = [
        AmbientSound(id: "rain", name: "Rain", symbol: "cloud.rain"),
        AmbientSound(id: "forest", name: "Forest", symbol: "tree"),
        AmbientSound(id: "waves", name: "Waves", symbol: "water.waves"),
        AmbientSound(id: "whiteNoise", name: "White Noise", symbol: "waveform"),
    ]
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `swift test --filter AmbientSoundTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/Sound/AmbientSound.swift Tests/FocusFlowKitTests/AmbientSoundTests.swift
git commit -m "feat(sound): add AmbientSound catalog"
```

### Task 2.2: `AmbientAudioEngine` protocol

**Files:**
- Create: `Sources/FocusFlowKit/Sound/AmbientAudioEngine.swift`

**Interfaces:**
- Produces: `public protocol AmbientAudioEngine: AnyObject { func play(_ id: String); func stop(_ id: String); func setVolume(_ volume: Double, for id: String); func stopAll() }`.

- [ ] **Step 1: Write implementation** (no test — pure protocol)

```swift
/// Controls looping ambient audio layers. The concrete AVFoundation impl
/// lives in the app target; the mixer view model sees only this protocol.
public protocol AmbientAudioEngine: AnyObject {
    func play(_ id: String)
    func stop(_ id: String)
    func setVolume(_ volume: Double, for id: String)   // 0.0...1.0
    func stopAll()
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/FocusFlowKit/Sound/AmbientAudioEngine.swift
git commit -m "feat(sound): add AmbientAudioEngine protocol"
```

### Task 2.3: `SoundMixerViewModel` (layers, volume, sleep timer)

**Files:**
- Create: `Sources/FocusFlowKit/State/SoundMixerViewModel.swift`
- Modify: `Tests/FocusFlowKitTests/Support/Fakes.swift` (add `AudioEngineSpy`)
- Test: `Tests/FocusFlowKitTests/SoundMixerViewModelTests.swift`

**Interfaces:**
- Consumes: `AmbientAudioEngine`, `AmbientSound`, `Clock`, `TimerTicker`.
- Produces: `@MainActor @Observable final class SoundMixerViewModel` with `init(engine: AmbientAudioEngine, clock: Clock = SystemClock(), ticker: TimerTicker)`, `func toggle(_ id: String)`, `func setVolume(_ v: Double, for id: String)`, `func isOn(_ id: String) -> Bool`, `func volume(for id: String) -> Double`, `func startSleepTimer(minutes: Int)`, `func cancelSleepTimer()`, `var sleepRemainingText: String?`.

- [ ] **Step 1: Add the spy to `Fakes.swift`**

```swift
/// Records calls made to the ambient audio engine.
final class AudioEngineSpy: AmbientAudioEngine {
    private(set) var playing: Set<String> = []
    private(set) var volumes: [String: Double] = [:]
    private(set) var stopAllCount = 0
    func play(_ id: String) { playing.insert(id) }
    func stop(_ id: String) { playing.remove(id) }
    func setVolume(_ volume: Double, for id: String) { volumes[id] = volume }
    func stopAll() { stopAllCount += 1; playing.removeAll() }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct SoundMixerViewModelTests {
    private func makeVM() -> (SoundMixerViewModel, AudioEngineSpy, FakeClock, FakeTicker) {
        let e = AudioEngineSpy(); let c = FakeClock(); let t = FakeTicker()
        return (SoundMixerViewModel(engine: e, clock: c, ticker: t), e, c, t)
    }

    @Test func togglingPlaysAndStops() {
        let (vm, engine, _, _) = makeVM()
        vm.toggle("rain")
        #expect(vm.isOn("rain")); #expect(engine.playing.contains("rain"))
        vm.toggle("rain")
        #expect(!vm.isOn("rain")); #expect(!engine.playing.contains("rain"))
    }

    @Test func settingVolumeForwardsToEngine() {
        let (vm, engine, _, _) = makeVM()
        vm.setVolume(0.4, for: "forest")
        #expect(engine.volumes["forest"] == 0.4)
        #expect(vm.volume(for: "forest") == 0.4)
    }

    @Test func sleepTimerStopsAllWhenElapsed() {
        let (vm, engine, clock, ticker) = makeVM()
        vm.toggle("rain")
        vm.startSleepTimer(minutes: 1)
        #expect(vm.sleepRemainingText == "01:00")
        clock.advance(by: 60); ticker.fire()
        #expect(engine.stopAllCount == 1)
        #expect(vm.sleepRemainingText == nil)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail** — Run: `swift test --filter SoundMixerViewModelTests` — Expected: FAIL (not in scope).

- [ ] **Step 4: Write implementation**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class SoundMixerViewModel {
    private struct Layer { var isOn: Bool; var volume: Double }
    private var layers: [String: Layer] = [:]
    public private(set) var sleepRemaining: TimeInterval?

    @ObservationIgnored private let engine: AmbientAudioEngine
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let ticker: TimerTicker
    @ObservationIgnored private var sleepEnd: Date?

    public init(engine: AmbientAudioEngine, clock: Clock = SystemClock(), ticker: TimerTicker) {
        self.engine = engine; self.clock = clock; self.ticker = ticker
    }

    public func isOn(_ id: String) -> Bool { layers[id]?.isOn ?? false }
    public func volume(for id: String) -> Double { layers[id]?.volume ?? 0.7 }

    public func toggle(_ id: String) {
        var layer = layers[id] ?? Layer(isOn: false, volume: 0.7)
        layer.isOn.toggle()
        layers[id] = layer
        if layer.isOn { engine.setVolume(layer.volume, for: id); engine.play(id) }
        else { engine.stop(id) }
    }

    public func setVolume(_ v: Double, for id: String) {
        var layer = layers[id] ?? Layer(isOn: false, volume: v)
        layer.volume = v; layers[id] = layer
        engine.setVolume(v, for: id)
    }

    public func startSleepTimer(minutes: Int) {
        sleepEnd = clock.now.addingTimeInterval(TimeInterval(minutes) * 60)
        sleepRemaining = TimeInterval(minutes) * 60
        ticker.start { [weak self] in Task { @MainActor in self?.tickSleep() } }
    }

    public func cancelSleepTimer() {
        ticker.stop(); sleepEnd = nil; sleepRemaining = nil
    }

    public var sleepRemainingText: String? {
        guard let r = sleepRemaining else { return nil }
        let s = max(0, Int(r.rounded(.up))); return String(format: "%02d:%02d", s / 60, s % 60)
    }

    func tickSleep() {
        guard let end = sleepEnd else { return }
        sleepRemaining = max(0, end.timeIntervalSince(clock.now))
        if sleepRemaining! <= 0 { engine.stopAll(); cancelSleepTimer() }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass** — Run: `swift test --filter SoundMixerViewModelTests` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/FocusFlowKit/State/SoundMixerViewModel.swift Tests/FocusFlowKitTests/Support/Fakes.swift Tests/FocusFlowKitTests/SoundMixerViewModelTests.swift
git commit -m "feat(sound): add SoundMixerViewModel with sleep timer"
```

### Task 2.4: `AVAmbientAudioEngine` (concrete) + bundled loops

**Files:**
- Create: `Services/AVAmbientAudioEngine.swift`
- Modify: `project.yml` (add `Resources/Sounds` to the `FocusFlow` target `sources`)
- Create: `Resources/Sounds/` (drop `rain.m4a`, `forest.m4a`, `waves.m4a`, `whiteNoise.m4a`; royalty-free loops)

**Interfaces:**
- Consumes: `AmbientAudioEngine` (Task 2.2).
- Produces: `final class AVAmbientAudioEngine: AmbientAudioEngine`.

- [ ] **Step 1: Implement `AVAmbientAudioEngine.swift`** (missing file → log + skip, never crash)

```swift
import AVFoundation
import FocusFlowKit

final class AVAmbientAudioEngine: AmbientAudioEngine {
    private var players: [String: AVAudioPlayer] = [:]

    func play(_ id: String) {
        if let p = players[id] { p.play(); return }
        guard let url = Bundle.main.url(forResource: id, withExtension: "m4a", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: id, withExtension: "m4a") else {
            NSLog("FocusFlow: ambient sound '\(id)' missing; skipping"); return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1; p.prepareToPlay(); p.play()
            players[id] = p
        } catch { NSLog("FocusFlow: failed to load '\(id)': \(error)") }
    }

    func stop(_ id: String) { players[id]?.stop(); players[id] = nil }
    func setVolume(_ volume: Double, for id: String) { players[id]?.volume = Float(volume) }
    func stopAll() { players.values.forEach { $0.stop() }; players.removeAll() }
}
```

- [ ] **Step 2: Register the resources folder** — In `project.yml`, under `targets: FocusFlow: sources:`, add a line `- path: Resources/Sounds`. (If you have no audio files yet, create the folder with a `.gitkeep` so the build still finds it; the engine logs-and-skips missing files.)

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodegen generate && xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Services/AVAmbientAudioEngine.swift project.yml Resources/Sounds
git commit -m "feat(sound): add AVFoundation ambient audio engine and sound resources"
```

### Task 2.5: Sound UI — `SoundTile` + `SoundMixerView`, wired into a tab

**Files:**
- Create: `Features/Sound/SoundTile.swift`
- Create: `Features/Sound/SoundMixerView.swift`
- Modify: `App/AppDelegate.swift` (build `soundMixerVM`), `Features/MenuBar/RootPopoverView.swift` + `PopoverTabBar.swift` (add a Sounds tab)

**Interfaces:**
- Consumes: `SoundMixerViewModel`, `AmbientSound`, `DesignTokens`.
- Produces: `SoundMixerView(vm: SoundMixerViewModel)`.

- [ ] **Step 1: Implement `SoundTile.swift`**

```swift
import SwiftUI
import FocusFlowKit

struct SoundTile: View {
    let sound: AmbientSound
    let isOn: Bool
    let volume: Double
    var onToggle: () -> Void
    var onVolume: (Double) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: sound.symbol)
                Text(sound.name).font(DesignTokens.bodySm)
                Spacer()
                Toggle("", isOn: Binding(get: { isOn }, set: { _ in onToggle() })).labelsHidden()
            }
            Slider(value: Binding(get: { volume }, set: onVolume), in: 0...1)
                .disabled(!isOn)
        }
        .padding(DesignTokens.stackTight)
        .background(isOn ? DesignTokens.surfaceContainerHigh : DesignTokens.surfaceContainerLow,
                    in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sound.name) layer")
    }
}
```

- [ ] **Step 2: Implement `SoundMixerView.swift`**

```swift
import SwiftUI
import FocusFlowKit

struct SoundMixerView: View {
    let vm: SoundMixerViewModel
    private let sleepOptions = [15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.elementGap) {
            Text("MIX").font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            ForEach(AmbientSound.all) { sound in
                SoundTile(sound: sound, isOn: vm.isOn(sound.id), volume: vm.volume(for: sound.id),
                          onToggle: { vm.toggle(sound.id) },
                          onVolume: { vm.setVolume($0, for: sound.id) })
            }
            Text("SLEEP TIMER").font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            HStack {
                ForEach(sleepOptions, id: \.self) { m in
                    Button("\(m)m") { vm.startSleepTimer(minutes: m) }.buttonStyle(.bordered)
                }
                Button("Off") { vm.cancelSleepTimer() }.buttonStyle(.bordered)
            }
            if let text = vm.sleepRemainingText {
                Text("Stops all sounds in \(text)").font(DesignTokens.monoLabel)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: DesignTokens.menuWidth)
        .background(DesignTokens.surface).foregroundStyle(DesignTokens.onSurface)
    }
}
```

- [ ] **Step 3: Add the `.sounds` case to `PopoverTab`** (symbol `"speaker.wave.2.fill"`, label `"Sounds"`) and render `SoundMixerView(vm: soundMixerVM)` in `RootPopoverView`'s switch; build `soundMixerVM` in `AppDelegate.init` with `AVAmbientAudioEngine()` and a fresh `DispatchSourceTimerTicker()`. (If `DesignTokens.monoLabel` / `surfaceContainerLow` are missing, add them mirroring existing tokens.)

- [ ] **Step 4: Build and run** — Run the build command, launch, open the Sounds tab, toggle a layer, set a sleep timer; confirm the countdown text appears. `pkill -f FocusFlow.app`.

- [ ] **Step 5: Commit**

```bash
git add Features/Sound Features/MenuBar App/AppDelegate.swift DesignSystem/DesignTokens.swift
git commit -m "feat(sound): add mixer UI and wire Sounds tab"
```

**Phase 2 checkpoint:** `swift test` green; Sounds tab mixes layers and the sleep timer stops playback.

---

# Phase 3 — Breathwork

A guided breathing engine (pure, clock-driven) plus a technique chooser (Ventura) and an immersive in-session view (Serene). Independently shippable; Phase 4 reuses the session view.

### Task 3.1: `BreathingPattern` + phase kinds

**Files:**
- Create: `Sources/FocusFlowKit/Breathwork/BreathingPattern.swift`
- Test: `Tests/FocusFlowKitTests/BreathingPatternTests.swift`

**Interfaces:**
- Produces:
  - `public enum BreathPhaseKind: String, Sendable, Equatable { case inhale, holdIn, exhale, holdOut; var label: String }`
  - `public struct BreathStep: Equatable, Sendable { public let kind: BreathPhaseKind; public let duration: TimeInterval }`
  - `public struct BreathingPattern: Identifiable, Equatable, Sendable { public let id: String; public let name: String; public let detail: String; public let steps: [BreathStep]; var cycleDuration: TimeInterval }`
  - `public extension BreathingPattern { static let all: [BreathingPattern] }` (box, four78, coherent, resonant).

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct BreathingPatternTests {
    @Test func boxBreathingHasFourEqualSteps() {
        let box = BreathingPattern.all.first { $0.id == "box" }!
        #expect(box.steps.count == 4)
        #expect(box.steps.allSatisfy { $0.duration == 4 })
        #expect(box.cycleDuration == 16)
    }
    @Test func fourSevenEightHasThreeSteps() {
        let p = BreathingPattern.all.first { $0.id == "four78" }!
        #expect(p.steps.map(\.duration) == [4, 7, 8])
        #expect(p.cycleDuration == 19)
    }
    @Test func catalogIdsAreUnique() {
        #expect(Set(BreathingPattern.all.map(\.id)).count == BreathingPattern.all.count)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** — Run: `swift test --filter BreathingPatternTests` — Expected: FAIL.

- [ ] **Step 3: Write implementation**

```swift
import Foundation

public enum BreathPhaseKind: String, Sendable, Equatable {
    case inhale, holdIn, exhale, holdOut
    public var label: String {
        switch self {
        case .inhale: "Inhale"; case .holdIn: "Hold"; case .exhale: "Exhale"; case .holdOut: "Hold"
        }
    }
}

public struct BreathStep: Equatable, Sendable {
    public let kind: BreathPhaseKind
    public let duration: TimeInterval
    public init(kind: BreathPhaseKind, duration: TimeInterval) { self.kind = kind; self.duration = duration }
}

public struct BreathingPattern: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let steps: [BreathStep]
    public init(id: String, name: String, detail: String, steps: [BreathStep]) {
        self.id = id; self.name = name; self.detail = detail; self.steps = steps
    }
    public var cycleDuration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }
}

public extension BreathingPattern {
    static let all: [BreathingPattern] = [
        BreathingPattern(id: "box", name: "Box Breathing", detail: "Calm and focus", steps: [
            .init(kind: .inhale, duration: 4), .init(kind: .holdIn, duration: 4),
            .init(kind: .exhale, duration: 4), .init(kind: .holdOut, duration: 4)]),
        BreathingPattern(id: "four78", name: "4-7-8 Breathing", detail: "Wind down and relax", steps: [
            .init(kind: .inhale, duration: 4), .init(kind: .holdIn, duration: 7),
            .init(kind: .exhale, duration: 8)]),
        BreathingPattern(id: "coherent", name: "Coherent Breathing", detail: "Find balance", steps: [
            .init(kind: .inhale, duration: 5), .init(kind: .exhale, duration: 5)]),
        BreathingPattern(id: "resonant", name: "Resonant", detail: "Steady rhythm", steps: [
            .init(kind: .inhale, duration: 6), .init(kind: .exhale, duration: 6)]),
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass** — Run: `swift test --filter BreathingPatternTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/Breathwork/BreathingPattern.swift Tests/FocusFlowKitTests/BreathingPatternTests.swift
git commit -m "feat(breathwork): add BreathingPattern catalog"
```

### Task 3.2: `BreathingSession` pure state machine

**Files:**
- Create: `Sources/FocusFlowKit/Breathwork/BreathingSession.swift`
- Test: `Tests/FocusFlowKitTests/BreathingSessionTests.swift`

**Interfaces:**
- Consumes: `BreathingPattern`, `BreathStep`, `BreathPhaseKind`.
- Produces: `public struct BreathingSession: Equatable, Sendable` with `init(pattern:targetCycles:)`, `var currentKind: BreathPhaseKind`, `var completedCycles: Int`, `var isFinished: Bool`, `func remaining(elapsed: TimeInterval) -> TimeInterval` (remaining in the *current* step), and `mutating func update(elapsed: TimeInterval)` where `elapsed` is total seconds since session start.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct BreathingSessionTests {
    private var box: BreathingPattern { BreathingPattern.all.first { $0.id == "box" }! }

    @Test func startsOnInhale() {
        let s = BreathingSession(pattern: box, targetCycles: 2)
        #expect(s.currentKind == .inhale)
        #expect(s.completedCycles == 0)
        #expect(!s.isFinished)
    }
    @Test func advancesThroughStepsByElapsedTime() {
        var s = BreathingSession(pattern: box, targetCycles: 2)
        s.update(elapsed: 5)    // 0-4 inhale, 4-8 holdIn
        #expect(s.currentKind == .holdIn)
        s.update(elapsed: 13)   // 12-16 holdOut
        #expect(s.currentKind == .holdOut)
    }
    @Test func countsCompletedCycles() {
        var s = BreathingSession(pattern: box, targetCycles: 2)
        s.update(elapsed: 16)           // one full 16s cycle done
        #expect(s.completedCycles == 1)
        #expect(s.currentKind == .inhale)
    }
    @Test func finishesAfterTargetCycles() {
        var s = BreathingSession(pattern: box, targetCycles: 2)
        s.update(elapsed: 32)
        #expect(s.completedCycles == 2)
        #expect(s.isFinished)
    }
    @Test func remainingCountsDownWithinCurrentStep() {
        let s = BreathingSession(pattern: box, targetCycles: 2)
        #expect(s.remaining(elapsed: 1) == 3)   // 1s into the 4s inhale
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** — Run: `swift test --filter BreathingSessionTests` — Expected: FAIL.

- [ ] **Step 3: Write implementation**

```swift
import Foundation

/// Pure, clock-driven guided-breathing state machine. Like PomodoroEngine it
/// holds no clock — the caller passes total `elapsed` seconds.
public struct BreathingSession: Equatable, Sendable {
    public let pattern: BreathingPattern
    public let targetCycles: Int
    public private(set) var completedCycles: Int = 0
    private var stepIndex: Int = 0

    public init(pattern: BreathingPattern, targetCycles: Int) {
        self.pattern = pattern; self.targetCycles = targetCycles
    }

    public var currentKind: BreathPhaseKind { pattern.steps[stepIndex].kind }
    public var isFinished: Bool { completedCycles >= targetCycles }

    /// Seconds left in the current step, given total elapsed seconds.
    public func remaining(elapsed: TimeInterval) -> TimeInterval {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return 0 }
        var within = elapsed.truncatingRemainder(dividingBy: cycle)
        for step in pattern.steps {
            if within < step.duration { return step.duration - within }
            within -= step.duration
        }
        return 0
    }

    /// Recomputes cycle count and current step from total elapsed seconds.
    public mutating func update(elapsed: TimeInterval) {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return }
        completedCycles = min(targetCycles, Int(elapsed / cycle))
        var within = elapsed.truncatingRemainder(dividingBy: cycle)
        var idx = 0
        for (i, step) in pattern.steps.enumerated() {
            if within < step.duration { idx = i; break }
            within -= step.duration
            idx = i
        }
        stepIndex = isFinished ? 0 : idx
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** — Run: `swift test --filter BreathingSessionTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/Breathwork/BreathingSession.swift Tests/FocusFlowKitTests/BreathingSessionTests.swift
git commit -m "feat(breathwork): add pure BreathingSession state machine"
```

### Task 3.3: `BreathingViewModel`

**Files:**
- Create: `Sources/FocusFlowKit/State/BreathingViewModel.swift`
- Test: `Tests/FocusFlowKitTests/BreathingViewModelTests.swift`

**Interfaces:**
- Consumes: `BreathingSession`, `BreathingPattern`, `Clock`, `TimerTicker`.
- Produces: `@MainActor @Observable final class BreathingViewModel` with `init(pattern:targetCycles:clock:ticker:)`, `func start()`, `func stop()`, `var phaseLabel: String`, `var cycleText: String`, `var isFinished: Bool`, `var stepProgress: Double` (0→1 within current step).

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct BreathingViewModelTests {
    private var box: BreathingPattern { BreathingPattern.all.first { $0.id == "box" }! }

    @Test func tracksPhaseAndCycleAsTimeAdvances() {
        let clock = FakeClock(); let ticker = FakeTicker()
        let vm = BreathingViewModel(pattern: box, targetCycles: 6, clock: clock, ticker: ticker)
        vm.start()
        #expect(vm.phaseLabel == "Inhale")
        #expect(vm.cycleText == "Cycle 1 of 6")
        clock.advance(by: 16); ticker.fire()
        #expect(vm.cycleText == "Cycle 2 of 6")
    }

    @Test func finishesAfterAllCycles() {
        let clock = FakeClock(); let ticker = FakeTicker()
        let vm = BreathingViewModel(pattern: box, targetCycles: 1, clock: clock, ticker: ticker)
        vm.start()
        clock.advance(by: 16); ticker.fire()
        #expect(vm.isFinished)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Run: `swift test --filter BreathingViewModelTests` — Expected: FAIL.

- [ ] **Step 3: Write implementation**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class BreathingViewModel {
    public private(set) var session: BreathingSession
    public private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let ticker: TimerTicker
    @ObservationIgnored private var startDate: Date?

    public init(pattern: BreathingPattern, targetCycles: Int,
                clock: Clock = SystemClock(), ticker: TimerTicker) {
        self.session = BreathingSession(pattern: pattern, targetCycles: targetCycles)
        self.clock = clock; self.ticker = ticker
    }

    public func start() {
        startDate = clock.now
        ticker.start { [weak self] in Task { @MainActor in self?.tick() } }
    }
    public func stop() { ticker.stop(); startDate = nil }

    public var phaseLabel: String { session.currentKind.label }
    public var cycleText: String { "Cycle \(min(session.completedCycles + 1, session.targetCycles)) of \(session.targetCycles)" }
    public var isFinished: Bool { session.isFinished }
    public var stepProgress: Double {
        let stepTotal = stepDuration()
        guard stepTotal > 0 else { return 0 }
        return min(1, max(0, 1 - session.remaining(elapsed: elapsed) / stepTotal))
    }

    func tick() {
        guard let startDate else { return }
        elapsed = clock.now.timeIntervalSince(startDate)
        session.update(elapsed: elapsed)
        if session.isFinished { stop() }
    }

    private func stepDuration() -> TimeInterval {
        session.pattern.steps.first { $0.kind == session.currentKind }?.duration ?? 0
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `swift test --filter BreathingViewModelTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/State/BreathingViewModel.swift Tests/FocusFlowKitTests/BreathingViewModelTests.swift
git commit -m "feat(breathwork): add BreathingViewModel"
```

### Task 3.4: Serene design tokens + breathwork views

**Files:**
- Create: `DesignSystem/SereneTokens.swift`
- Create: `Features/Breathwork/TechniqueChooserView.swift`
- Create: `Features/Breathwork/BreathingSessionView.swift`

**Interfaces:**
- Consumes: `BreathingPattern`, `BreathingViewModel`, `SereneTokens`.
- Produces: `TechniqueChooserView(selection: Binding<BreathingPattern>, onStart: () -> Void)`; `BreathingSessionView(vm: BreathingViewModel, onEnd: () -> Void)`.

- [ ] **Step 1: Implement `SereneTokens.swift`** (from the `Serene Interval` design system)

```swift
import SwiftUI

enum SereneTokens {
    static let surface = Color(red: 0.07, green: 0.08, blue: 0.086)   // #121416
    static let onSurface = Color(red: 0.886, green: 0.886, blue: 0.898)
    static let sage = Color(red: 0.729, green: 0.796, blue: 0.71)     // #bacbb5
    static let mistyBlue = Color(red: 0.698, green: 0.792, blue: 0.847) // #b2cad8
    static let secondaryText = Color(red: 0.769, green: 0.784, blue: 0.749)
    static var breathGradient: LinearGradient {
        LinearGradient(colors: [sage, mistyBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
```

- [ ] **Step 2: Implement `TechniqueChooserView.swift`**

```swift
import SwiftUI
import FocusFlowKit

struct TechniqueChooserView: View {
    @Binding var selection: BreathingPattern
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.elementGap) {
            ForEach(BreathingPattern.all) { pattern in
                Button { selection = pattern } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.name).font(DesignTokens.headlineMd)
                        Text(pattern.detail).font(DesignTokens.bodySm)
                            .foregroundStyle(DesignTokens.secondaryText)
                        HStack(spacing: 4) {
                            ForEach(Array(pattern.steps.enumerated()), id: \.offset) { _, step in
                                Text("\(Int(step.duration))").font(DesignTokens.monoLabel)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(DesignTokens.surfaceContainerHigh, in: Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.stackTight)
                    .background(DesignTokens.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(selection.id == pattern.id ? DesignTokens.accent(for: .focus) : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Button(action: onStart) {
                Text("Start Session").frame(maxWidth: .infinity).padding(8)
                    .background(DesignTokens.accent(for: .focus), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: DesignTokens.menuWidth)
        .background(DesignTokens.surface).foregroundStyle(DesignTokens.onSurface)
    }
}
```

- [ ] **Step 3: Implement `BreathingSessionView.swift`** (Serene, full-screen)

```swift
import SwiftUI
import FocusFlowKit

struct BreathingSessionView: View {
    let vm: BreathingViewModel
    var onEnd: () -> Void

    var body: some View {
        ZStack {
            SereneTokens.surface.ignoresSafeArea()
            RadialGradient(colors: [SereneTokens.sage.opacity(0.18), .clear],
                           center: .center, startRadius: 1, endRadius: 480).ignoresSafeArea()
            VStack(spacing: 28) {
                Text(vm.session.pattern.name.uppercased())
                    .font(.system(.caption, design: .monospaced)).tracking(2)
                    .foregroundStyle(SereneTokens.sage)
                Text(vm.cycleText).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(SereneTokens.secondaryText)
                ZStack {
                    Circle().stroke(SereneTokens.sage.opacity(0.2), lineWidth: 6).frame(width: 240, height: 240)
                    Circle().trim(from: 0, to: vm.stepProgress)
                        .stroke(SereneTokens.sage, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 240, height: 240)
                    Text(vm.phaseLabel).font(.system(size: 44, weight: .light, design: .default))
                        .foregroundStyle(SereneTokens.onSurface)
                }
                Button(action: onEnd) {
                    Text("End Session").padding(.horizontal, 24).padding(.vertical, 10)
                        .overlay(Capsule().stroke(SereneTokens.mistyBlue, lineWidth: 1))
                }
                .buttonStyle(.plain).foregroundStyle(SereneTokens.onSurface)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodegen generate && xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DesignSystem/SereneTokens.swift Features/Breathwork
git commit -m "feat(breathwork): add Serene tokens, technique chooser, and session view"
```

**Phase 3 checkpoint:** `swift test` green; breathwork engine fully tested and views compile. (Surfaced in the UI by Phase 4's break flow.)

---

# Phase 4 — Relaxation / Break Flow

Ties it together: when a focus session ends, present a full-screen break-start prompt; offer guided breathing during the break; on break end show a break-complete prompt. Reuses `BreathingSessionView` and `SereneTokens`.

### Task 4.1: `BreakPrompt` decision helper

**Files:**
- Create: `Sources/FocusFlowKit/Breathwork/BreakPrompt.swift`
- Test: `Tests/FocusFlowKitTests/BreakPromptTests.swift`

**Interfaces:**
- Consumes: `PomodoroPhase`.
- Produces: `public enum BreakPromptKind: Equatable, Sendable { case start(PomodoroPhase), complete, none }` and `public enum BreakPrompt { public static func onTransition(finished: PomodoroPhase, next: PomodoroPhase) -> BreakPromptKind }`.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import FocusFlowKit

@Suite struct BreakPromptTests {
    @Test func focusToBreakShowsStart() {
        #expect(BreakPrompt.onTransition(finished: .focus, next: .shortBreak) == .start(.shortBreak))
        #expect(BreakPrompt.onTransition(finished: .focus, next: .longBreak) == .start(.longBreak))
    }
    @Test func breakToFocusShowsComplete() {
        #expect(BreakPrompt.onTransition(finished: .shortBreak, next: .focus) == .complete)
        #expect(BreakPrompt.onTransition(finished: .longBreak, next: .focus) == .complete)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** — Run: `swift test --filter BreakPromptTests` — Expected: FAIL.

- [ ] **Step 3: Write implementation**

```swift
public enum BreakPromptKind: Equatable, Sendable {
    case start(PomodoroPhase)   // a break is beginning
    case complete               // a break just ended
    case none
}

public enum BreakPrompt {
    public static func onTransition(finished: PomodoroPhase, next: PomodoroPhase) -> BreakPromptKind {
        if finished == .focus, next.isBreak { return .start(next) }
        if finished.isBreak, next == .focus { return .complete }
        return .none
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** — Run: `swift test --filter BreakPromptTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/Breathwork/BreakPrompt.swift Tests/FocusFlowKitTests/BreakPromptTests.swift
git commit -m "feat(relaxation): add BreakPrompt transition helper"
```

### Task 4.2: Expose a phase-transition callback on `TimerViewModel`

**Files:**
- Modify: `Sources/FocusFlowKit/State/TimerViewModel.swift`
- Test: `Tests/FocusFlowKitTests/TimerViewModelTransitionTests.swift`

**Interfaces:**
- Produces: `public var onPhaseTransition: ((_ finished: PomodoroPhase, _ next: PomodoroPhase) -> Void)?` invoked inside `completePhase()` after the engine advances.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import FocusFlowKit

@MainActor
@Suite struct TimerViewModelTransitionTests {
    @Test func firesCallbackOnPhaseCompletion() {
        let clock = FakeClock(); let ticker = FakeTicker()
        let vm = TimerViewModel(
            settings: PomodoroSettings(focusDuration: 10, shortBreakDuration: 5,
                                       longBreakDuration: 8, longBreakInterval: 4),
            ticker: ticker, clock: clock, notifications: NotificationSpy(), sound: SoundSpy())
        var captured: [(PomodoroPhase, PomodoroPhase)] = []
        vm.onPhaseTransition = { f, n in captured.append((f, n)) }
        vm.start(); clock.advance(by: 10); vm.tick()
        #expect(captured.count == 1)
        #expect(captured.first?.0 == .focus)
        #expect(captured.first?.1 == .shortBreak)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Run: `swift test --filter TimerViewModelTransitionTests` — Expected: FAIL (no member `onPhaseTransition`).

- [ ] **Step 3: Modify `TimerViewModel`** — Add the property near the other public state:

```swift
    /// Fired after a phase completes and the engine advances. The app uses
    /// this to drive the full-screen break flow.
    @ObservationIgnored public var onPhaseTransition: ((PomodoroPhase, PomodoroPhase) -> Void)?
```
At the end of `completePhase()`, after `loadCurrentPhase()`:

```swift
        onPhaseTransition?(finished, engine.currentPhase)
```

- [ ] **Step 4: Run tests to verify they pass** — Run: `swift test --filter TimerViewModelTransitionTests` then `swift test` — Expected: PASS, all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusFlowKit/State/TimerViewModel.swift Tests/FocusFlowKitTests/TimerViewModelTransitionTests.swift
git commit -m "feat(relaxation): expose phase-transition callback on TimerViewModel"
```

### Task 4.3: Break prompt views

**Files:**
- Create: `Features/Relaxation/BreakStartView.swift`
- Create: `Features/Relaxation/BreakCompleteView.swift`

**Interfaces:**
- Consumes: `SereneTokens`.
- Produces: `BreakStartView(minutes: Int, onStartBreath: () -> Void, onStartBreak: () -> Void, onSkip: () -> Void)`; `BreakCompleteView(onResume: () -> Void, onExtend: () -> Void)`.

- [ ] **Step 1: Implement `BreakStartView.swift`**

```swift
import SwiftUI

struct BreakStartView: View {
    let minutes: Int
    var onStartBreath: () -> Void
    var onStartBreak: () -> Void
    var onSkip: () -> Void

    var body: some View {
        SereneScaffold {
            Text("FOCUS COMPLETE").font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(SereneTokens.sage)
            Text("Time for a break").font(.system(size: 40, weight: .light))
            Text("You've focused well. Take \(minutes) to recharge.")
                .foregroundStyle(SereneTokens.secondaryText)
            VStack(spacing: 12) {
                SereneButton("Start Break", filled: true, action: onStartBreak)
                SereneButton("Breathe", filled: false, action: onStartBreath)
                SereneButton("Skip break", filled: false, action: onSkip)
            }.padding(.top, 16)
        }
    }
}
```

- [ ] **Step 2: Implement `BreakCompleteView.swift` + shared `SereneScaffold`/`SereneButton`** (put the two shared helpers at the bottom of this file)

```swift
import SwiftUI

struct BreakCompleteView: View {
    var onResume: () -> Void
    var onExtend: () -> Void
    var body: some View {
        SereneScaffold {
            Image(systemName: "checkmark").font(.title).foregroundStyle(SereneTokens.sage)
                .frame(width: 56, height: 56).overlay(Circle().stroke(SereneTokens.sage.opacity(0.4)))
            Text("BREAK COMPLETE").font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(SereneTokens.sage)
            Text("Break's over").font(.system(size: 40, weight: .light))
            Text("Ready to get back into deep focus?").foregroundStyle(SereneTokens.secondaryText)
            HStack(spacing: 12) {
                SereneButton("Resume Focus", filled: true, action: onResume)
                SereneButton("Extend 5 min", filled: false, action: onExtend)
            }.padding(.top, 16)
        }
    }
}

struct SereneScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            SereneTokens.surface.ignoresSafeArea()
            RadialGradient(colors: [SereneTokens.sage.opacity(0.16), .clear],
                           center: .topLeading, startRadius: 1, endRadius: 600).ignoresSafeArea()
            VStack(spacing: 16) { content }.multilineTextAlignment(.center)
        }
        .frame(minWidth: 640, minHeight: 480)
        .foregroundStyle(SereneTokens.onSurface)
    }
}

struct SereneButton: View {
    let title: String; let filled: Bool; let action: () -> Void
    init(_ title: String, filled: Bool, action: @escaping () -> Void) {
        self.title = title; self.filled = filled; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(title).frame(width: 220).padding(.vertical, 12)
                .background { if filled { Capsule().fill(SereneTokens.breathGradient) } else { Capsule().stroke(SereneTokens.mistyBlue.opacity(0.6)) } }
                .foregroundStyle(filled ? SereneTokens.surface : SereneTokens.onSurface)
        }.buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Build to verify it compiles** — Run the build command — Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Features/Relaxation
git commit -m "feat(relaxation): add break start/complete prompt views"
```

### Task 4.4: `BreakFlowCoordinator` — full-screen window + wiring

**Files:**
- Create: `App/BreakFlowCoordinator.swift`
- Modify: `App/AppDelegate.swift`

**Interfaces:**
- Consumes: `TimerViewModel.onPhaseTransition`, `BreakPrompt`, `BreathingViewModel`, the Relaxation/Breathwork views.
- Produces: `@MainActor final class BreakFlowCoordinator` with `init(timerVM:)` that owns a borderless full-screen `NSWindow` and shows the right view per `BreakPromptKind`.

- [ ] **Step 1: Implement `BreakFlowCoordinator.swift`**

```swift
import AppKit
import SwiftUI
import FocusFlowKit

/// Drives the full-screen break experience off the timer's phase transitions.
/// Reuses the borderless-window pattern from AppDelegate's aux windows.
@MainActor
final class BreakFlowCoordinator {
    private let timerVM: TimerViewModel
    private var window: NSWindow?

    init(timerVM: TimerViewModel) {
        self.timerVM = timerVM
        timerVM.onPhaseTransition = { [weak self] finished, next in
            self?.handle(BreakPrompt.onTransition(finished: finished, next: next))
        }
    }

    private func handle(_ kind: BreakPromptKind) {
        switch kind {
        case .start(let phase):
            present(AnyView(BreakStartView(
                minutes: Int(timerVM.engine.settings.duration(for: phase) / 60),
                onStartBreath: { [weak self] in self?.presentBreathing() },
                onStartBreak: { [weak self] in self?.timerVM.start(); self?.dismiss() },
                onSkip: { [weak self] in self?.timerVM.skip(); self?.dismiss() })))
        case .complete:
            present(AnyView(BreakCompleteView(
                onResume: { [weak self] in self?.timerVM.start(); self?.dismiss() },
                onExtend: { [weak self] in self?.dismiss() })))
        case .none:
            break
        }
    }

    private func presentBreathing() {
        let pattern = BreathingPattern.all.first { $0.id == "box" }!
        let vm = BreathingViewModel(pattern: pattern, targetCycles: 6, ticker: DispatchSourceTimerTicker())
        present(AnyView(BreathingSessionView(vm: vm, onEnd: { [weak self] in self?.dismiss() })))
    }

    private func present(_ view: AnyView) {
        let window = self.window ?? makeFullScreenWindow()
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func dismiss() { window?.orderOut(nil) }

    private func makeFullScreenWindow() -> NSWindow {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        return window
    }
}
```

- [ ] **Step 2: Own the coordinator in `AppDelegate`** — Add `private var breakFlow: BreakFlowCoordinator?` and create it in `applicationDidFinishLaunching`:

```swift
        breakFlow = BreakFlowCoordinator(timerVM: timerVM)
```
(Set it after launch, not in `init`, so `onPhaseTransition` is wired once the graph is live.)

- [ ] **Step 3: Build and run the full flow** — Build, launch, set a short focus duration in Preferences (e.g. via the stepper) or wait out a focus session; on completion the full-screen break-start appears with Start Break / Breathe / Skip; "Breathe" shows the guided ring; finishing the break shows break-complete. `pkill -f FocusFlow.app`.

- [ ] **Step 4: Run the full kit suite** — Run: `swift test` — Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add App/BreakFlowCoordinator.swift App/AppDelegate.swift
git commit -m "feat(relaxation): add full-screen break flow coordinator"
```

**Phase 4 checkpoint:** `swift test` green; end-to-end break flow works. Optional tag: `git tag v1.4-relaxation`.

---

## Notes & Deferred Polish

- **Audio assets:** Task 2.4 needs four royalty-free looping `.m4a` files in `Resources/Sounds`. Until they exist the engine logs-and-skips (no crash); the mixer UI still functions.
- **Stats persistence location:** SwiftData defaults to the app's Application Support container — sandbox-safe. No migration needed for v1 of the schema.
- **Theme application** remains the known accepted gap from v1 (theme picker persists but isn't applied to window chrome) — out of scope here.
- Each phase is independently shippable and tagged; if scope needs to shrink, ship after any phase checkpoint.
