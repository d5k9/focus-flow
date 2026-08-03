import SwiftUI
import FocusFlowKit

/// One to-do row: completion toggle, title, pomodoro count, active marker.
/// Tapping the row makes it the active task; done rows cannot be activated.
struct TaskRow: View {
    let item: TaskItem
    let isActive: Bool
    var onToggleDone: () -> Void
    var onActivate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.stackTight) {
            Button(action: onToggleDone) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? DesignTokens.relaxGreen : DesignTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.title) not done" : "Complete \(item.title)")

            Text(item.title)
                .font(DesignTokens.bodySm)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? DesignTokens.secondaryText : DesignTokens.onSurface)
                .lineLimit(1)

            Spacer(minLength: DesignTokens.unit)

            if item.completedPomodoros > 0 {
                Label("\(item.completedPomodoros)", systemImage: "timer")
                    .font(DesignTokens.monoLabel)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .accessibilityLabel("\(item.completedPomodoros) sessions")
            }

            Circle()
                .fill(DesignTokens.accent(for: .focus))
                .frame(width: 6, height: 6)
                .opacity(isActive ? 1 : 0)
                .accessibilityHidden(!isActive)
                .accessibilityLabel("Active task")
        }
        .padding(.horizontal, DesignTokens.stackTight)
        .frame(minHeight: DesignTokens.rowMinHeight)
        .background(isActive ? DesignTokens.surfaceContainerHigh : .clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusControl))
        .contentShape(Rectangle())
        .onTapGesture { if !item.isDone { onActivate() } }
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
