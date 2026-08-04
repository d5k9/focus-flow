# FocusFlow Main Window Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn FocusFlow from a menu-bar popover into a conventional Mac app with a resizable main window and sidebar navigation, keeping the menu-bar countdown as a companion.

**Architecture:** `LSUIElement` off; an `AppDelegate`-owned `NSWindow` hosts a `NavigationSplitView` with four sections; the SwiftUI `App` keeps only a `Settings` scene and a `.menu`-style `MenuBarExtra`. Every fixed 280pt width in the section views becomes flexible. `FocusFlowKit` is not touched.

**Tech Stack:** SwiftUI + AppKit interop, XcodeGen, Swift Testing (kit only).

**Spec:** `docs/superpowers/specs/2026-08-04-focusflow-window-shell-design.md`

## Global Constraints

- **Do not modify anything under `Sources/FocusFlowKit/` or `Tests/`.** This is a presentation-layer change; `swift test` must still report 109 passing tests at the end, unchanged.
- Never edit `FocusFlow.xcodeproj` — it is generated. Edit `project.yml`, then `xcodegen generate`.
- App build: `xcodegen generate` then `xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- Built app path: `~/Library/Developer/Xcode/DerivedData/FocusFlow-advkjbmerxbpkoeooisoayrvwetb/Build/Products/Debug/FocusFlow.app`. Always `pkill -x FocusFlow` before relaunching, or two menu-bar icons and two timers appear.
- No new design tokens — use the existing `DesignTokens`.
- Window: default 900×600, minimum 700×460. Sidebar 180pt (min 160, max 220). Content caps: Timer 480pt, Tasks 640pt.
- `DesignTokens.menuWidth` (280) stays defined; it must simply stop constraining section content.
- **Leave `Features/Breathwork/TechniqueChooserView.swift` alone.** It also has a 280pt frame, but it is currently dead code — `BreakFlowCoordinator` hard-codes the "box" pattern and never presents it. It is not reachable from the window, so changing it here is churn. Same for `BreathingSessionView` and the break views, which are full-screen by design.

---

### Task 1: Give the app a Dock icon

**Files:**
- Modify: `project.yml:38` (`LSUIElement: true` → `false`)
- Modify: `Resources/Info.plist` (`LSUIElement` `<true/>` → `<false/>`)

Both must change. XcodeGen's `info.properties` does not override a checked-in plist, so editing only one leaves the app an agent with no Dock icon — the failure looks like "my change did nothing".

- [ ] **Step 1: Flip both flags.** In `project.yml` under `targets.FocusFlow.info.properties`, set `LSUIElement: false`. In `Resources/Info.plist`, change the `LSUIElement` value element from `<true/>` to `<false/>`.
- [ ] **Step 2: Rebuild and verify Dock presence.**

```bash
pkill -x FocusFlow; xcodegen generate
xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
plutil -p ~/Library/Developer/Xcode/DerivedData/FocusFlow-advkjbmerxbpkoeooisoayrvwetb/Build/Products/Debug/FocusFlow.app/Contents/Info.plist | grep -i lsuielement
```

Expected: `BUILD SUCCEEDED` and `"LSUIElement" => 0`. If it prints `1`, one of the two files was missed.

- [ ] **Step 3: Commit** — `feat(shell): give FocusFlow a Dock icon`

---

### Task 2: Sidebar navigation view

**Files:**
- Create: `Features/MainWindow/AppSection.swift`
- Create: `Features/MainWindow/MainWindowView.swift`

**Interfaces:**
- Produces: `enum AppSection` and `struct MainWindowView: View { init(delegate: AppDelegate) }`.
- Consumes: `delegate.timerVM`, `delegate.tasksVM`, `delegate.statsVM`, `delegate.soundMixerVM` — resolved inside the `switch` so lazy view models stay lazy.

- [ ] **Step 1: Write `AppSection`:**

```swift
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case timer, tasks, stats, sounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .tasks: "Tasks"
        case .stats: "Stats"
        case .sounds: "Sounds"
        }
    }

    var symbol: String {
        switch self {
        case .timer: "timer"
        case .tasks: "checklist"
        case .stats: "chart.bar.fill"
        case .sounds: "speaker.wave.2.fill"
        }
    }
}
```

- [ ] **Step 2: Write `MainWindowView`.** Note the `switch` resolves one view model only — that preserves the lazy construction from the previous pass. `TimerSectionView` and the flexible section views arrive in Tasks 4–6; this will not compile standalone until Task 4, which is expected.

```swift
import SwiftUI
import FocusFlowKit

struct MainWindowView: View {
    let delegate: AppDelegate
    /// Optional because that is the type `List` selection binds to; `current`
    /// collapses it back to a concrete section for the detail pane.
    @State private var section: AppSection? = .timer

    private var current: AppSection { section ?? .timer }

    var body: some View {
        NavigationSplitView {
            // Explicit ForEach + .tag, not `List(data, selection:)` — the
            // latter binds selection to the element's ID type (String here),
            // which will not type-check against an AppSection binding.
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol).tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.surface)
                .foregroundStyle(DesignTokens.onSurface)
                .navigationTitle(current.title)
        }
    }

    @ViewBuilder private var detail: some View {
        switch current {
        case .timer:
            TimerSectionView(vm: delegate.timerVM,
                             tasksVM: delegate.tasksVM,
                             onPickTask: { section = .tasks })
        case .tasks:  TasksView(vm: delegate.tasksVM)
        case .stats:  StatsView(vm: delegate.statsVM)
        case .sounds: SoundMixerView(vm: delegate.soundMixerVM)
        }
    }
}
```

- [ ] **Step 3: Commit** — `feat(shell): add sidebar navigation view` (build comes after Task 4; commit the files now so the diff stays reviewable)

---

### Task 3: Menu-bar companion menu

**Files:**
- Create: `App/MenuBarCommands.swift`

**Interfaces:**
- Produces: `struct MenuBarCommands: View { init(timerVM: TimerViewModel, onShowWindow: @escaping () -> Void) }`

- [ ] **Step 1: Write the menu.** Buttons inside a `MenuBarExtra` without `.menuBarExtraStyle(.window)` render as menu items:

```swift
import SwiftUI
import AppKit
import FocusFlowKit

/// The menu-bar item's menu. The countdown in the label is the point of
/// keeping a menu-bar presence at all; these commands make the transport
/// reachable without raising the window.
struct MenuBarCommands: View {
    let timerVM: TimerViewModel
    var onShowWindow: () -> Void

    var body: some View {
        Button("Show FocusFlow", action: onShowWindow)
        Divider()
        Button(timerVM.isRunning ? "Pause" : "Start") { timerVM.toggle() }
        Button("Skip") { timerVM.skip() }
        Button("Reset") { timerVM.reset() }
        Divider()
        Button("Quit FocusFlow") { NSApp.terminate(nil) }
    }
}
```

- [ ] **Step 2: Commit** — `feat(shell): add menu-bar companion menu`

---

### Task 4: Timer section — flexible, no header

**Files:**
- Delete: `Features/Timer/TimerPopoverView.swift`
- Create: `Features/Timer/TimerSectionView.swift`
- Modify: `Features/Timer/TimerReadout.swift` (add `diameter`)

**Interfaces:**
- Produces: `TimerSectionView(vm:tasksVM:onPickTask:)`; `TimerReadout(vm:diameter:)` with `diameter` defaulting to 160.

- [ ] **Step 1: Add the `diameter` parameter to `TimerReadout`** so the window can ask for a larger ring without a second copy of the view. Keep the per-second reads inside this body — that is the whole reason the view exists:

```swift
struct TimerReadout: View {
    let vm: TimerViewModel
    var diameter: CGFloat = 160

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
        .frame(width: diameter, height: diameter)
        .padding(.vertical, DesignTokens.stackTight)
    }
}
```

- [ ] **Step 2: Write `TimerSectionView`** — the old `TimerPopoverView` minus its header row and gear button (the window has a title bar and ⌘, now), minus the fixed 280pt width, with the content centred and capped:

```swift
import SwiftUI
import FocusFlowKit

struct TimerSectionView: View {
    let vm: TimerViewModel
    let tasksVM: TasksViewModel
    var onPickTask: () -> Void = {}

    private var accent: Color { DesignTokens.accent(for: vm.phase) }

    var body: some View {
        VStack(spacing: DesignTokens.elementGap) {
            Spacer(minLength: 0)
            TimerReadout(vm: vm, diameter: 220)
            controls
            ActiveTaskChip(vm: tasksVM, onPick: onPickTask)
            SessionList(currentPhase: vm.phase)
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.containerPadding)
        .frame(maxWidth: 480)
    }

    private var controls: some View {
        HStack(spacing: DesignTokens.elementGap) {
            iconButton("arrow.counterclockwise", label: "Reset timer", action: vm.reset)
            Button(action: vm.toggle) {
                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vm.isRunning ? "Pause" : "Start")
            iconButton("forward.fill", label: "Skip", action: vm.skip)
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(DesignTokens.onSurface)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DesignTokens.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
```

- [ ] **Step 3: Delete `Features/Timer/TimerPopoverView.swift`.**
- [ ] **Step 4: Verify no stale references** — `grep -rn "TimerPopoverView" App Features` must return nothing except matches you are about to fix in Task 7.
- [ ] **Step 5: Commit** — `feat(shell): make the timer section flexible`

---

### Task 5: Tasks and Stats sections at full width

**Files:**
- Modify: `Features/Tasks/TasksView.swift:30` (remove fixed width, unclamp the scroll)
- Modify: `Features/Stats/StatsView.swift:9` (remove fixed width, taller chart)

- [ ] **Step 1: `TasksView`** — replace `.frame(width: DesignTokens.menuWidth)` with `.frame(maxWidth: 640)`, and remove the `.frame(maxHeight: 260)` on the `ScrollView` so the list fills the pane. Keep everything else as-is.
- [ ] **Step 2: `StatsView`** — replace `.frame(width: DesignTokens.menuWidth)` with `.frame(maxWidth: 640)`. In `barChart`, change the bar height expression from `8 + 64 * (bucket.totalFocus / maxFocus)` to `16 + 128 * (bucket.totalFocus / maxFocus)` and the container `.frame(height: 80)` to `.frame(height: 160)`.
- [ ] **Step 3: Commit** — `feat(shell): let tasks and stats use the window width`

---

### Task 6: Sounds section as a grid

**Files:**
- Modify: `Features/Sound/SoundMixerView.swift:31`

- [ ] **Step 1: Replace the vertical stack of tiles with an adaptive grid** and drop the fixed width. The `ForEach(AmbientSound.all)` over `SoundTile` becomes:

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: DesignTokens.stackTight)],
          spacing: DesignTokens.stackTight) {
    ForEach(AmbientSound.all) { sound in
        SoundTile(sound: sound, isOn: vm.isOn(sound.id), volume: vm.volume(for: sound.id),
                  onToggle: { vm.toggle(sound.id) },
                  onVolume: { vm.setVolume($0, for: sound.id) })
    }
}
```

Replace the view's `.frame(width: DesignTokens.menuWidth)` with `.frame(maxWidth: 640)`.

- [ ] **Step 2: Commit** — `feat(shell): lay out sound tiles in a grid`

---

### Task 7: Wire up the shell

**Files:**
- Modify: `App/FocusFlowApp.swift` (replace the whole body)
- Modify: `App/AppDelegate.swift` (own the main window; delete `showPreferences`/`preferencesWindow`)
- Delete: `Features/MenuBar/RootPopoverView.swift`, `Features/MenuBar/PopoverTabBar.swift`

**Interfaces:**
- Consumes: `MainWindowView` (Task 2), `MenuBarCommands` (Task 3), `TimerSectionView` (Task 4).
- Produces: `AppDelegate.showMainWindow()`.

- [ ] **Step 1: Rewrite `FocusFlowApp`:**

```swift
import SwiftUI

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Supplies Cmd-, and the "Settings…" app-menu item; replaces the
        // hand-rolled preferences window.
        Settings {
            PreferencesView(settings: appDelegate.settings)
        }

        MenuBarExtra {
            MenuBarCommands(
                timerVM: appDelegate.timerVM,
                onShowWindow: { appDelegate.showMainWindow() })
        } label: {
            MenuBarLabel(vm: appDelegate.timerVM)
        }
    }
}
```

- [ ] **Step 2: Add the main window to `AppDelegate`.** Add a `private var mainWindow: NSWindow?` alongside the existing `onboardingWindow`, and:

```swift
/// The app's primary window. Owned here rather than declared as a SwiftUI
/// `Window` scene so it can be raised from anywhere — the menu-bar item, a
/// Dock click — without depending on scene restoration.
func showMainWindow() {
    if let mainWindow {
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
    window.title = "FocusFlow"
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 700, height: 460)
    window.setFrameAutosaveName("FocusFlowMainWindow")
    window.contentView = NSHostingView(rootView: MainWindowView(delegate: self))
    window.center()
    mainWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

/// Re-raises the window when the Dock icon is clicked with no visible windows.
func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { showMainWindow() }
    return true
}
```

- [ ] **Step 3: Show it at launch, and after onboarding.** In `applicationDidFinishLaunching`, after `observeSettings()`, call `showMainWindow()` only when onboarding is not being presented:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    Task { _ = await notifications.requestAuthorization() }
    observeSettings()
    breakFlow = BreakFlowCoordinator(timerVM: timerVM)
    if settings.hasCompletedOnboarding {
        showMainWindow()
    } else {
        showOnboarding()
    }
}
```

and in `showOnboarding()`'s completion closure, after `onboardingWindow?.close()`, add `self?.showMainWindow()` so a first-run user lands in the app. Delete the now-unused `showOnboardingIfNeeded()`.

- [ ] **Step 4: Delete the preferences window code** — the `showPreferences()` method and the `preferencesWindow` property. The `Settings` scene replaces both.
- [ ] **Step 5: Delete the popover views** — `Features/MenuBar/RootPopoverView.swift` and `Features/MenuBar/PopoverTabBar.swift`. `MenuBarLabel.swift` stays.
- [ ] **Step 6: Confirm nothing references the deleted symbols:**

```bash
grep -rn "RootPopoverView\|PopoverTabBar\|PopoverTab\|showPreferences\|onOpenPreferences\|TimerPopoverView" App Features
```

Expected: no output.

- [ ] **Step 7: Build** — `xcodegen generate && xcodebuild ... build`. Expected: BUILD SUCCEEDED. This is the first task where everything compiles together.
- [ ] **Step 8: Commit** — `feat(shell): replace the popover with a main window`

---

### Task 8: Verify by looking at it

- [ ] **Step 1: Kit regression check** — `swift test`. Expected: 109 tests pass, unchanged. This proves the shell rework did not reach into the kit.
- [ ] **Step 2: Launch and confirm the window and Dock icon:**

```bash
pkill -x FocusFlow; open ~/Library/Developer/Xcode/DerivedData/FocusFlow-advkjbmerxbpkoeooisoayrvwetb/Build/Products/Debug/FocusFlow.app
sleep 4; pgrep -x FocusFlow && osascript -e 'tell application "System Events" to get name of every window of process "FocusFlow"'
```

Expected: a pid, and a window named "FocusFlow". If AppleScript is blocked by automation permissions, fall back to `screencapture` in the next step and note the limitation.

- [ ] **Step 3: Screenshot and actually look at it.** `screencapture -l` needs a CoreGraphics window id that no shell tool reports without a helper, so capture the screen and read the image:

```bash
screencapture -x /tmp/ff-timer.png && echo captured
```

Then **Read `/tmp/ff-timer.png` with the Read tool and inspect it.** A screenshot nobody looks at verifies nothing. Check: the sidebar shows four labelled rows, the detail pane fills the window, the ring is the larger 220pt one, nothing is clipped to a 280pt column, nothing is absurdly stretched.

To reach the other three sections, clicking a sidebar row needs System Events UI automation:

```bash
osascript -e 'tell application "System Events" to tell process "FocusFlow" to click row 2 of outline 1 of scroll area 1 of splitter group 1 of window 1'
```

This requires Accessibility permission for the terminal. If it fails, **do not fake it** — capture the Timer section, state plainly that the other three were not visually verified, and say why.

- [ ] **Step 4: Confirm the window close behaviour** — close the window (⌘W via System Events if available), then check `pgrep -x FocusFlow` still returns a pid and the menu-bar item is still present. The timer must survive; a focus timer that dies with its window is a bug.
- [ ] **Step 5: Record what could not be verified.** Anything needing a real click — driving transport buttons, typing a task, switching sections if automation is blocked — is reported as unverified, not assumed working.
- [ ] **Step 6: Commit** — `docs: record main-window shell verification results`
