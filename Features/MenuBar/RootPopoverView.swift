import SwiftUI
import FocusFlowKit

struct RootPopoverView: View {
    let timerVM: TimerViewModel
    let statsVM: StatsViewModel
    let soundMixerVM: SoundMixerViewModel
    var onOpenPreferences: () -> Void = {}
    @State private var tab: PopoverTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .timer: TimerPopoverView(vm: timerVM, onOpenPreferences: onOpenPreferences)
            case .stats: StatsView(vm: statsVM)
            case .sounds: SoundMixerView(vm: soundMixerVM)
            case .settings: TimerPopoverView(vm: timerVM, onOpenPreferences: onOpenPreferences)
            }
            PopoverTabBar(selection: $tab, onSettings: onOpenPreferences)
                .frame(width: DesignTokens.menuWidth)
        }
        .background(DesignTokens.surface)
    }
}
