import SwiftUI

enum PopoverTab: CaseIterable { case timer, stats, settings
    var symbol: String { switch self { case .timer: "timer"; case .stats: "chart.bar.fill"; case .settings: "gearshape.fill" } }
    var label: String { switch self { case .timer: "Timer"; case .stats: "Stats"; case .settings: "Settings" } }
}

struct PopoverTabBar: View {
    @Binding var selection: PopoverTab
    var onSettings: () -> Void
    var body: some View {
        HStack {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                Button {
                    if tab == .settings { onSettings() } else { selection = tab }
                } label: {
                    Image(systemName: tab.symbol)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(tab == selection ? DesignTokens.accent(for: .focus) : DesignTokens.secondaryText)
                        .accessibilityLabel(tab.label)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignTokens.stackTight)
        .background(DesignTokens.surfaceContainerHigh)
    }
}
