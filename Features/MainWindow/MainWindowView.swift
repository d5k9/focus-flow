import SwiftUI
import FocusFlowKit

/// Root of the main window: a sidebar of sections and a detail pane.
///
/// Takes the delegate rather than each view model so that the `switch` below
/// resolves only the visited section's model — stats and sounds stay lazily
/// constructed, as does the SwiftData container behind them.
struct MainWindowView: View {
    let delegate: AppDelegate
    /// Optional because that is what `List` selection binds to; `current`
    /// collapses it back to a concrete section for the detail pane.
    @State private var section: AppSection? = .timer

    private var current: AppSection { section ?? .timer }

    var body: some View {
        NavigationSplitView {
            // Explicit ForEach + .tag, not `List(data, selection:)` — the
            // latter binds selection to the element's ID type (String here),
            // which does not type-check against an AppSection binding.
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol).tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.surface)
                .foregroundStyle(DesignTokens.onSurface)
                .navigationTitle(current.title)
        }
    }

    @ViewBuilder private var detail: some View {
        switch current {
        case .timer:
            TimerSectionView(
                vm: delegate.timerVM,
                tasksVM: delegate.tasksVM,
                onPickTask: { section = .tasks })
        case .tasks:  TasksView(vm: delegate.tasksVM)
        case .stats:  StatsView(vm: delegate.statsVM)
        case .sounds: SoundMixerView(vm: delegate.soundMixerVM)
        }
    }
}
