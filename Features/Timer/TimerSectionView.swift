import SwiftUI
import FocusFlowKit

/// The Timer section of the main window. No header row or gear button — the
/// window has a title bar and Preferences lives behind ⌘, now.
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
