import SwiftUI
import FocusFlowKit

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
