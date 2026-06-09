import SwiftUI
import FocusFlowKit

struct TimerPopoverView: View {
    let vm: TimerViewModel
    var onOpenPreferences: () -> Void = {}
    var body: some View {
        VStack(spacing: 12) {
            Text(vm.displayTime).font(.largeTitle.monospacedDigit())
            Button(vm.isRunning ? "Pause" : "Start") { vm.toggle() }
        }
        .padding()
        .frame(width: 280)
    }
}
