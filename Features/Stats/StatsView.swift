import SwiftUI
import FocusFlowKit

struct StatsView: View {
    let vm: StatsViewModel

    var body: some View {
        Group { if vm.isEmpty { emptyState } else { content } }
            .frame(width: DesignTokens.menuWidth)
            .background(DesignTokens.surface)
            .foregroundStyle(DesignTokens.onSurface)
            .onAppear { vm.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.stackTight) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle).foregroundStyle(DesignTokens.secondaryText)
            Text("No sessions yet").font(DesignTokens.headlineMd)
            Text("Complete your first focus session to start tracking your streak and daily totals.")
                .font(DesignTokens.bodySm).multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(DesignTokens.containerPadding)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.elementGap) {
            HStack(spacing: DesignTokens.stackTight) {
                StatCard(label: "Total Focus", value: vm.totalFocusText)
                StatCard(label: "Daily Avg", value: vm.dailyAverageText)
                StatCard(label: "Streak", value: vm.currentStreakText)
            }
            Text("LAST 7 DAYS").font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            barChart
        }
        .padding(DesignTokens.containerPadding)
    }

    private var barChart: some View {
        let maxFocus = max(1, vm.summary.last7Days.map(\.totalFocus).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(vm.summary.last7Days.enumerated()), id: \.offset) { _, bucket in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bucket.sessionCount > 0 ? DesignTokens.accent(for: .focus) : DesignTokens.surfaceContainerHigh)
                    .frame(height: 8 + 64 * (bucket.totalFocus / maxFocus))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
    }
}
