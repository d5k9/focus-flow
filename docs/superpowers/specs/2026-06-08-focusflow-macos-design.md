# FocusFlow — macOS Menu-Bar App: Architectural Design

**Date:** 2026-06-08
**Status:** Approved (design phase)
**Source design:** Stitch project "Menu Bar Focus Timer" / theme *Ventura Focus* (`projects/14492833859784039326`)

## Overview

FocusFlow is a native macOS **menu-bar Pomodoro/focus app** with a dark, glassmorphic
aesthetic. It lives in the menu bar (no Dock icon), runs focus/break cycles, and surfaces
its state in a popover and live in the menu-bar title.

The full design comprises seven screens (timer, preferences, breathwork preferences,
activity stats, relaxation mode, meditative sounds, onboarding). This spec defines the
**v1 = Core Timer MVP** and an architecture that lets the remaining feature areas
(stats, ambient sounds, breathwork, full-screen relaxation) layer in without rework.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Tech stack | Native Swift / SwiftUI (+ AppKit interop where needed) | Best fit and footprint for an always-on menu-bar utility; native menu-bar, notification, and sound APIs |
| v1 scope | Core Timer MVP | Ships a genuinely useful app fast; the spine everything else hangs off |
| Persistence | `UserDefaults` (settings) + SwiftData (stats, later) | Apple-native, minimal boilerplate |
| Distribution | Notarized DMG now; App-Store-ready later | Pet project flexibility, keep sandbox path open |
| Deployment target | **macOS 26 (minimum)** | All modern APIs available; Liquid Glass delivers the glassmorphic look natively |

## v1 Scope (Core Timer MVP)

In scope:
- Menu-bar icon + popover (timer ring, play/pause/reset, session list)
- Live `MM:SS` countdown in the menu-bar title while running
- Pomodoro engine: focus / short break / long break cycles, long break every N focus sessions
- Preferences: timer durations, notification toggles (sound effects, desktop alerts), theme
- Onboarding (first-run welcome window)
- Completion notifications + sound chime

Explicitly deferred (architecture accommodates, v1 does not build):
- Activity stats & history (SwiftData)
- Ambient/meditative sound player + library
- Breathwork / guided breathing
- Full-screen relaxation mode

## App Shell & Lifecycle

- **`MenuBarExtra`** scene with `.menuBarExtraStyle(.window)` — native menu-bar icon with a
  popover-style SwiftUI window. No manual `NSStatusItem`/`NSPopover` plumbing for v1.
- **`LSUIElement = YES`** (agent app) — menu-bar only, no Dock icon.
- Menu-bar **label shows live `MM:SS`** while a session runs; idle shows the app glyph.
- **Preferences** and **Onboarding** are separate `Window`/`Settings` scenes. The eventual
  full-screen Relaxation Mode reuses this borderless-window pattern.

## Layered Architecture

```
Presentation (SwiftUI Views)        thin, declarative
        │
State / ViewModels (@Observable)    TimerViewModel, SettingsStore
        │
Domain (pure Swift, no Apple deps)  PomodoroEngine  ← the heart, fully unit-tested
        │
Services (infrastructure)           TimerTicker, NotificationService, SoundService, Persistence
```

Each layer depends only downward. The domain layer has **zero** Apple-framework
dependencies so it can be reasoned about and tested in isolation.

### Domain layer

- **`PomodoroEngine`** — pure value-type state machine. Owns: current phase
  (`focus / shortBreak / longBreak`), completed-focus count, cycle config, transitions,
  and `pause` / `resume` / `skip` / `reset`. Computes the next phase (long break every
  N focus sessions). No timer, no clock of its own — it is *driven*. This is where the
  logic-bugs live, so it is isolated and tested hard.
- **`PomodoroPhase`** — enum of phases with associated durations.
- **`PomodoroSettings`** — durations + cycle interval (long-break-every-N).

### Services layer

- **`TimerTicker`** — protocol over the clock. Live implementation uses
  `DispatchSourceTimer`; tests inject a fake clock.
  **Critical rule:** anchor to an absolute end-`Date` and recompute remaining time from
  `Date()` on each tick, rather than decrementing a counter. This keeps the timer accurate
  across sleep/wake and timer throttling instead of drifting.
- **`NotificationService`** — wraps `UNUserNotificationCenter`; requests authorization,
  posts desktop alerts on phase completion.
- **`SoundService`** — plays completion chimes (AVFoundation / `NSSound`). Stub seam for
  the future ambient-sound player.
- **`SettingsStore`** — typed wrapper over `UserDefaults`. SwiftData `ModelContainer` is
  wired but dormant until stats are built.

### State / ViewModels

- **`TimerViewModel`** (`@Observable`) — owns engine + ticker, exposes published state
  (remaining time, phase, running flag, session list) to views, handles user intents.
- **`SettingsStore`** — observable settings surface for Preferences.

### Presentation

- `MenuBarLabel` — status-item glyph / live countdown.
- `TimerPopoverView` — ring (`ProgressRing`), controls, session list.
- `PreferencesView` — durations, notification toggles, theme.
- `OnboardingView` — first-run welcome.

## Design System

Translate the Stitch `design.md` tokens into a Swift **`DesignTokens`** type
(colors, type scale, spacing, radii). On macOS 26, the **Liquid Glass** material provides
the glassmorphic surface natively; a thin `VisualEffectBlur` (`NSViewRepresentable` over
`NSVisualEffectView`) remains available as a fallback for custom surfaces. `ProgressRing`
is the reusable circular timer stroke (track + active arc, pill-rounded).

## File Layout

```
FocusFlow/
  App/            FocusFlowApp.swift, AppDelegate.swift
  Domain/         PomodoroEngine.swift, PomodoroPhase.swift, PomodoroSettings.swift
  Services/       TimerTicker.swift, NotificationService.swift, SoundService.swift, SettingsStore.swift
  Features/
    MenuBar/      MenuBarLabel.swift
    Timer/        TimerPopoverView.swift, TimerViewModel.swift
    Preferences/  PreferencesView.swift
    Onboarding/   OnboardingView.swift
  DesignSystem/   DesignTokens.swift, VisualEffectBlur.swift, ProgressRing.swift
  Resources/      Assets.xcassets, sounds/
  Tests/          PomodoroEngineTests.swift, SettingsStoreTests.swift
```

## Data Flow

1. User taps **Start** → `TimerViewModel.start()` → `PomodoroEngine.start()` sets the
   end-anchor `Date`.
2. `TimerTicker` fires each second → VM recomputes remaining from `Date()` → publishes.
3. SwiftUI updates the ring and the menu-bar label.
4. Phase end → engine transitions to next phase → `NotificationService` posts an alert and
   `SoundService` plays a chime → UI advances.

## Error Handling

- **Notification authorization denied** → degrade to in-app indication only; surface a
  subtle hint in Preferences; never crash.
- **Missing sound asset** → log and skip; never crash.
- **Settings read failure** → fall back to documented defaults.

## App-Store Readiness

All v1 capabilities (notifications, sound, local persistence) are sandbox-safe. The app is
built to stay within App Sandbox so the future Mac App Store path requires only
build-configuration and entitlement changes, not architectural ones. Hardened-runtime /
notarization are handled at the release-build step (out of scope for the architecture).

## Testing Strategy

- **`PomodoroEngine`** — exhaustive unit tests with a fake clock: phase transitions,
  long-break interval, pause/resume, skip, reset, and boundary conditions.
- **`SettingsStore`** — round-trip persistence tests.
- **Views** kept thin; verified manually / via light snapshot checks.

## Open Items

None blocking. Future feature specs (stats, sounds, breathwork, relaxation) will each get
their own spec → plan → implementation cycle.
