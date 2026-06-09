import SwiftUI
import FocusFlowKit

/// Menu-bar title: live MM:SS while running, app glyph when idle.
struct MenuBarLabel: View {
    let vm: TimerViewModel
    var body: some View {
        if vm.isRunning {
            Text(vm.displayTime).monospacedDigit()
        } else {
            Image(systemName: "timer")
        }
    }
}
