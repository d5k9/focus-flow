# FocusFlow

FocusFlow is a native Pomodoro timer for macOS 26. It is a SwiftUI app with a main window and a menu-bar item. The menu-bar item shows the live countdown.

## Features

- **Pomodoro timer.** The timer runs focus, short break, and long break phases. The defaults are 25, 5, and 15 minutes. A long break replaces the short break after every 4 focus sessions. You can change all of these values in Settings.
- **Menu-bar countdown.** The menu bar shows the remaining time (`MM:SS`) while the timer runs. Its menu has the Start/Pause, Skip, Reset, and Show FocusFlow commands.
- **Tasks.** Keep a to-do list. Click a task to make it the active task. FocusFlow counts each completed focus session against the active task.
- **Stats.** See your total focus time, daily average, current streak, and a bar chart of the last 7 days. FocusFlow keeps the session history on your Mac with SwiftData.
- **Ambient sounds.** Play rain, forest, waves, and white noise together, each with its own volume. A sleep timer stops the sounds after a set time.
- **Break flow.** When a focus session ends, a full-screen prompt starts the break. From this prompt, you can start a guided box-breathing session. A second prompt shows when the break ends.
- **Onboarding.** A welcome window shows at the first launch.
- **Settings** (`⌘,`). Set the phase durations, sound effects, desktop alerts, and theme.

## Requirements

| Item | Version |
|---|---|
| macOS | 26.0 or later |
| Xcode | 26 or later (tested with 26.2) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Tested with 2.44.1 |

## Build and run

The repository does not contain the Xcode project. XcodeGen makes it from `project.yml`.

1. Install XcodeGen:

   ```sh
   brew install xcodegen
   ```

2. Make the Xcode project:

   ```sh
   xcodegen generate
   ```

3. Build the app:

   ```sh
   xcodebuild -project FocusFlow.xcodeproj -scheme FocusFlow \
     -destination 'platform=macOS' -derivedDataPath DerivedData \
     CODE_SIGNING_ALLOWED=NO build
   ```

4. Start the app:

   ```sh
   open DerivedData/Build/Products/Debug/FocusFlow.app
   ```

You can also open `FocusFlow.xcodeproj` in Xcode and run the `FocusFlow` scheme.

`CODE_SIGNING_ALLOWED=NO` lets you build the app without a signing identity. To sign the app, put your team ID in `DEVELOPMENT_TEAM` in `project.yml`. Then run `xcodegen generate` again.

> [!IMPORTANT]
> Do not edit `FocusFlow.xcodeproj` directly. XcodeGen replaces it each time it runs. Make all project changes in `project.yml`.

## Run the tests

The `FocusFlowKit` package contains the app logic and its tests. Run the tests with SwiftPM:

```sh
swift test
```

The tests use Swift Testing. They do not need the Xcode project or a signing identity.

## Project structure

FocusFlow has two parts:

- **`FocusFlowKit`** is a Swift package at the repository root (`Package.swift`). It contains the domain logic, services, persistence, and view models. It has no views, and unit tests cover it.
- **The app target** is a thin SwiftUI and AppKit layer on top of the package. XcodeGen makes its project from `project.yml`.

| Path | Contents |
|---|---|
| `Sources/FocusFlowKit/Domain/` | The `PomodoroEngine` state machine, phases, and settings |
| `Sources/FocusFlowKit/Services/` | Clock, timer ticker, settings store, and protocols for notifications and sound |
| `Sources/FocusFlowKit/State/` | `@Observable` view models |
| `Sources/FocusFlowKit/Stats/` | Focus session records, SwiftData storage, and stats aggregation |
| `Sources/FocusFlowKit/Tasks/` | The task list and its SwiftData storage |
| `Sources/FocusFlowKit/Sound/` | The ambient sound catalog and audio engine protocol |
| `Sources/FocusFlowKit/Breathwork/` | Breathing patterns, the breathing session, and break prompts |
| `Tests/FocusFlowKitTests/` | Unit tests for the package |
| `App/` | App entry point, `AppDelegate`, menu-bar commands, and the break flow coordinator |
| `Features/` | SwiftUI views for each feature |
| `Services/` | Implementations for AVFoundation audio, system sounds, and user notifications |
| `DesignSystem/` | Design tokens and shared view components |
| `Resources/` | Asset catalog, `Info.plist`, entitlements, and sound files |

Design rules:

- Each layer depends only on the layers below it. The domain layer uses only Foundation.
- The timer keeps an absolute end time. On each tick, it calculates the remaining time from the clock. Thus the timer stays correct when the Mac sleeps or when macOS delays timers.
- The package uses the Swift 5 language mode. Strict concurrency checks are for a later change.

## Known limits

- The repository contains no ambient sound files. To use the Sounds section, add `rain.m4a`, `forest.m4a`, `waves.m4a`, and `whiteNoise.m4a` to `Resources/Sounds/`. Then run `xcodegen generate` again.
- The app icon is an empty placeholder.
- The app saves the Theme setting, but it does not apply it yet.
- Desktop notifications need a signed build.
- The break flow always uses box breathing. The package also has 4-7-8, coherent, and resonant patterns, but the app does not let you select them yet.

## License

FocusFlow is available under the MIT License. See [LICENSE](LICENSE).
