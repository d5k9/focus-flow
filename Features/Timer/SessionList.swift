import SwiftUI
import FocusFlowKit

/// "Next up" style list of the three phases; the active phase is highlighted
/// and tinted with its accent color.
struct SessionList: View {
    let currentPhase: PomodoroPhase

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PomodoroPhase.allCases, id: \.self) { phase in
                SessionRow(phase: phase, isActive: phase == currentPhase)
                if phase != PomodoroPhase.allCases.last {
                    Rectangle()
                        .fill(DesignTokens.separator)
                        .frame(height: 1)
                }
            }
        }
    }
}

private struct SessionRow: View {
    let phase: PomodoroPhase
    let isActive: Bool

    var body: some View {
        HStack(spacing: DesignTokens.stackTight) {
            Circle()
                .fill(DesignTokens.accent(for: phase).opacity(isActive ? 1 : 0.2))
                .frame(width: 8, height: 8)
            Text(phase.title)
                .font(DesignTokens.bodySm)
                .foregroundStyle(isActive ? DesignTokens.onSurface : DesignTokens.secondaryText)
            Spacer()
        }
        .frame(minHeight: DesignTokens.rowMinHeight)
        .padding(.horizontal, DesignTokens.stackTight)
    }
}
