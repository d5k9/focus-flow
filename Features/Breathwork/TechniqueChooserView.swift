import SwiftUI
import FocusFlowKit

struct TechniqueChooserView: View {
    @Binding var selection: BreathingPattern
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.elementGap) {
            ForEach(BreathingPattern.all) { pattern in
                Button { selection = pattern } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.name).font(DesignTokens.headlineMd)
                        Text(pattern.detail).font(DesignTokens.bodySm)
                            .foregroundStyle(DesignTokens.secondaryText)
                        HStack(spacing: 4) {
                            ForEach(Array(pattern.steps.enumerated()), id: \.offset) { _, step in
                                Text("\(Int(step.duration))").font(DesignTokens.monoLabel)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(DesignTokens.surfaceContainerHigh, in: Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.stackTight)
                    .background(DesignTokens.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(selection.id == pattern.id ? DesignTokens.accent(for: .focus) : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Button(action: onStart) {
                Text("Start Session").frame(maxWidth: .infinity).padding(8)
                    .background(DesignTokens.accent(for: .focus), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: DesignTokens.menuWidth)
        .background(DesignTokens.surface).foregroundStyle(DesignTokens.onSurface)
    }
}
