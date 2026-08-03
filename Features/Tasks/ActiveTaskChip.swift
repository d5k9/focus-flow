import SwiftUI
import FocusFlowKit

/// Shows what the running session is being counted against, so you don't have
/// to switch tabs to check. Reads only `TasksViewModel`, so per-second timer
/// ticks never invalidate it.
struct ActiveTaskChip: View {
    let vm: TasksViewModel
    var onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: DesignTokens.stackTight) {
                Image(systemName: "checklist")
                    .foregroundStyle(DesignTokens.secondaryText)
                if let item = vm.activeItem {
                    Text(item.title)
                        .font(DesignTokens.bodySm)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.unit)
                    if item.completedPomodoros > 0 {
                        Text("\(item.completedPomodoros)")
                            .font(DesignTokens.monoLabel)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                } else {
                    Text("No task selected")
                        .font(DesignTokens.bodySm)
                        .foregroundStyle(DesignTokens.secondaryText)
                    Spacer(minLength: DesignTokens.unit)
                }
            }
            .padding(.horizontal, DesignTokens.stackTight)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusControl))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vm.activeItem.map { "Active task: \($0.title)" } ?? "Choose a task")
    }
}
