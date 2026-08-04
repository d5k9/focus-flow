import SwiftUI
import AppKit
import FocusFlowKit

/// The menu-bar item's menu. The live countdown in the label is the reason to
/// keep a menu-bar presence at all; these commands make the transport
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
