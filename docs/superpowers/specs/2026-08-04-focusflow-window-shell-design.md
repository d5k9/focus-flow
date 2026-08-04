# FocusFlow — Main Window Shell: Design

**Date:** 2026-08-04
**Status:** Approved (design phase)
**Builds on:** `2026-06-08-focusflow-macos-design.md` (v1 architecture), `2026-08-03-focusflow-tasks-and-performance-design.md`

## Overview

FocusFlow currently lives entirely in a `MenuBarExtra` popover: 280pt wide, dismissed by any
click outside it, no Dock presence. That is a poor host for a task list — the surface you
type into disappears the moment you look at something else.

This change makes FocusFlow a conventional Mac app with a resizable main window and
sidebar navigation, and demotes the menu-bar item to a companion that keeps the glanceable
countdown.

Nothing below the presentation layer changes. `FocusFlowKit` — domain, services, and every
view model — is untouched, which is the payoff of having kept the shell thin.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Dock presence | `LSUIElement: false` | Real app: Dock icon, app menu, ⌘-Tab |
| Main window owner | AppKit `NSWindow` created by `AppDelegate` | Deterministic show/hide/re-raise; matches the pattern Preferences and the break window already use here |
| Navigation | `NavigationSplitView` sidebar, four sections | macOS idiom; gives Tasks the width it wants |
| Preferences | SwiftUI `Settings` scene | ⌘, and the app-menu item for free; deletes hand-rolled window code |
| Menu-bar item | `.menu` style with transport commands | Keeps the live countdown, drops the cramped popover |
| Window close | App keeps running, timer keeps ticking | A focus timer that dies when you close a window is a bug |

## Scene Structure

The SwiftUI `App` keeps two scenes; the main window is not one of them.

```swift
@main struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { PreferencesView(settings: appDelegate.settings) }

        MenuBarExtra { MenuBarCommands(...) } label: { MenuBarLabel(vm: appDelegate.timerVM) }
    }
}
```

- **`Settings` scene** supplies ⌘, and the "Settings…" app-menu item. `AppDelegate.showPreferences()`
  and its `preferencesWindow` property are **deleted**, along with the gear button's plumbing
  through the view hierarchy.
- **Main window** is created by `AppDelegate.showMainWindow()`: an `NSWindow` with
  `[.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]`, content set to
  `NSHostingView(rootView: MainWindowView(delegate: self))`, `isReleasedWhenClosed = false`,
  and `setFrameAutosaveName("FocusFlowMainWindow")` for frame persistence.
- Default size 900×600, minimum 700×460.
- Called from `applicationDidFinishLaunching` (unless onboarding is showing) and from
  `applicationShouldHandleReopen(_:hasVisibleWindows:)`, which re-raises it on Dock click and
  returns `true`.
- Closing the window is not termination. `NSApplication` only quits on last-window-close if
  the delegate opts in, and this one does not — so no code is needed, but the intent is
  recorded here because it is load-bearing: the timer must keep running.

**Why not SwiftUI's `Window` scene.** It is less code, but recovering a closed window from
the menu-bar item and from a Dock click then depends on scene-restoration behaviour, and
`openWindow` is only reachable from inside a scene's view tree. An `AppDelegate`-owned window
is explicit, has one obvious entry point callable from anywhere, and reuses a pattern already
proven in this codebase. Frame persistence — the main thing the scene would have given us —
is one line of `setFrameAutosaveName`.

## Menu-Bar Companion

`MenuBarExtra` drops `.menuBarExtraStyle(.window)` and becomes a standard menu:

- Label: `MenuBarLabel` unchanged — live `MM:SS` while running, the timer glyph when idle.
- **Show FocusFlow** → `appDelegate.showMainWindow()`
- Divider
- **Start** / **Pause** (title follows `timerVM.isRunning`) → `timerVM.toggle()`
- **Skip** → `timerVM.skip()`
- **Reset** → `timerVM.reset()`
- Divider
- **Quit FocusFlow** → `NSApp.terminate(nil)`

This is the whole reason to keep a menu-bar presence: the countdown stays visible when the
window is behind an editor, and the transport is reachable without raising the window.

## Sidebar Navigation

`Features/MainWindow/MainWindowView.swift` replaces `RootPopoverView`:

```swift
enum AppSection: String, CaseIterable, Identifiable {
    case timer, tasks, stats, sounds
    var id: String { rawValue }
    var title: String { ... }        // "Timer", "Tasks", "Stats", "Sounds"
    var symbol: String { ... }       // "timer", "checklist", "chart.bar.fill", "speaker.wave.2.fill"
}
```

A `NavigationSplitView` with a `List(selection:)` sidebar over `AppSection.allCases` and a
detail pane switching on the selection. Sidebar width 180, `navigationSplitViewColumnWidth`
min 160 / max 220. Selection is `@State`, defaulting to `.timer`.

The detail pane resolves each section's view model at the point of use, so the lazy
construction from the previous pass is preserved: visiting Timer must not build the audio
engine.

The active-task chip's `onPick` closure — which previously switched the popover tab — now
sets the sidebar selection to `.tasks`. That is the same idea in the new navigation, and it
is what makes "No task selected" actionable.

**Deleted:** `Features/MenuBar/RootPopoverView.swift`, `Features/MenuBar/PopoverTabBar.swift`
(and with it the `PopoverTab` enum). `MenuBarLabel.swift` stays.

## Making the Views Flexible

Six views hard-code `.frame(width: DesignTokens.menuWidth)`. Five are section content and
must become flexible; the sixth is not reachable from the window and is left alone.

| View | Change |
|---|---|
| `TimerPopoverView` | Renamed `TimerSectionView`. Ring grows to 220pt via a parameter on `TimerReadout`; content centred and capped at 480pt. Header row and its gear button are removed — the window has a title bar and ⌘, now. |
| `TasksView` | Full-width rows and add field; content capped at 640pt. Drops the internal `maxHeight: 260` scroll clamp and scrolls to fill the pane instead. |
| `StatsView` | Stat cards spread across the pane (`StatCard` already uses `maxWidth: .infinity`); 7-day chart height 80 → 160. |
| `SoundMixerView` | Tiles move from a vertical stack into `LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))])`. |
| `TimerReadout` | Gains a `diameter: CGFloat = 160` parameter so the window can ask for 220 without a second copy of the view. |
| `TechniqueChooserView` | **Untouched.** It is currently dead code — `BreakFlowCoordinator` hard-codes the "box" pattern and never presents the chooser. Wiring it up is a separate piece of work; changing its width here would be churn. |

`DesignTokens.menuWidth` stays — the menu-bar label and any future popover still want it —
but no longer constrains section content. No new design tokens; the existing palette,
spacing, and type ramp carry over unchanged.

## What Stays Put

- **Onboarding** keeps its own `AppDelegate`-owned window. Folding it into a sheet on the
  main window is an optional cleanup, not part of this change. On first run it is shown and
  the main window is not, so the welcome screen is not competing with a window behind it;
  its completion handler — which already closes the window and sets
  `hasCompletedOnboarding` — then calls `showMainWindow()`, so a first-run user lands in the
  app rather than staring at an empty desktop.
- **`BreakFlowCoordinator`** and the full-screen break flow are unaffected — they already
  own a borderless window independent of the popover.
- **`FocusFlowKit`** in its entirety. No view model, protocol, or domain type changes.

## Build Configuration

`project.yml`: `LSUIElement: true` → `false`. `Resources/Info.plist` carries a hard-coded
`LSUIElement` `<true/>` as well, and XcodeGen's `info.properties` does not override a
checked-in plist — **both** must change, or the app keeps its agent behaviour and the Dock
icon never appears.

## Testing & Verification

The app target has no test harness — kit tests cover the layer below, and this change does
not touch it. `swift test` must still pass unchanged (109 tests), which is the regression
check that the shell rework did not reach into the kit.

Verification is therefore build, launch, and *look*:

1. `xcodegen generate` and build clean.
2. Launch; confirm a Dock icon appears and the main window opens.
3. `screencapture -l $(window id)` each of the four sections and inspect the images —
   sidebar renders, content fills the pane, nothing is clipped at 280pt or stretched
   absurdly at 900pt.
4. Resize to the 700×460 minimum and screenshot again: no clipping, no overlap.
5. Close the window; confirm the process survives and the menu-bar countdown continues.
6. Re-raise from the menu-bar **Show FocusFlow** item and from a Dock click.
7. ⌘, opens Preferences.

This is a real improvement in what can be verified: a normal window can be captured and
examined, which a menu-bar popover could not be. Screenshots go in the report. Anything that
still needs a click I cannot perform — driving the transport buttons, typing in the task
field — is called out as unverified rather than assumed.

## File Layout Delta

```
App/
  FocusFlowApp.swift        Settings + MenuBarExtra scenes only
  AppDelegate.swift         owns the main NSWindow; showPreferences/preferencesWindow deleted
  MenuBarCommands.swift     new: the menu-bar menu items
Features/
  MainWindow/               new: MainWindowView.swift (NavigationSplitView + AppSection)
  MenuBar/                  RootPopoverView.swift and PopoverTabBar.swift deleted
  Timer/                    TimerPopoverView.swift -> TimerSectionView.swift; TimerReadout gains diameter
  Tasks/, Stats/, Sound/    fixed widths removed
project.yml, Resources/Info.plist   LSUIElement false in both
```
