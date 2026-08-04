import SwiftUI
import FocusFlowKit

/// The only view that reads per-second timer state. Kept separate from
/// `TimerSectionView` so a tick invalidates this body alone rather than the
/// whole section. It must take the view model — passing `vm.progress` and
/// `vm.displayTime` in from the parent would move the observable read back up
/// and undo the split.
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
