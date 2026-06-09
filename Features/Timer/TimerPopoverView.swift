import SwiftUI
import FocusFlowKit

struct TimerPopoverView: View {
    let vm: TimerViewModel
    var onOpenPreferences: () -> Void = {}

    private var accent: Color { DesignTokens.accent(for: vm.phase) }

    var body: some View {
        VStack(spacing: DesignTokens.elementGap) {
            header
            ringSection
            controls
            SessionList(currentPhase: vm.phase)
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: DesignTokens.menuWidth)
        .background(DesignTokens.surface)
        .foregroundStyle(DesignTokens.onSurface)
    }

    private var header: some View {
        HStack {
            Text("FocusFlow").font(DesignTokens.headlineMd)
            Spacer()
            Button(action: onOpenPreferences) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preferences")
        }
    }

    private var ringSection: some View {
        ZStack {
            ProgressRing(progress: vm.progress, tint: accent)
            VStack(spacing: 2) {
                Text(vm.displayTime).font(DesignTokens.timerDisplay)
                Text(vm.phase.title.uppercased())
                    .font(DesignTokens.labelCaps)
                    .tracking(0.5)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .frame(width: 160, height: 160)
        .padding(.vertical, DesignTokens.stackTight)
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
