import SwiftUI
import FocusFlowKit

/// Takes the delegate rather than each view model, so only the visited tab's
/// model is resolved. Passing `delegate.statsVM` and `delegate.soundMixerVM`
/// as init arguments would force every lazy view model — and its audio engine
/// and ticker — as soon as the popover was built.
struct RootPopoverView: View {
    let delegate: AppDelegate
    var onOpenPreferences: () -> Void = {}
    @State private var tab: PopoverTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .timer: TimerPopoverView(vm: delegate.timerVM, onOpenPreferences: onOpenPreferences)
            case .stats: StatsView(vm: delegate.statsVM)
            case .sounds: SoundMixerView(vm: delegate.soundMixerVM)
            case .settings: TimerPopoverView(vm: delegate.timerVM, onOpenPreferences: onOpenPreferences)
            }
            PopoverTabBar(selection: $tab, onSettings: onOpenPreferences)
                .frame(width: DesignTokens.menuWidth)
        }
        .background(DesignTokens.surface)
    }
}
