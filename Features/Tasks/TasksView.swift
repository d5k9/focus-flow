import SwiftUI
import FocusFlowKit

struct TasksView: View {
    let vm: TasksViewModel
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.stackTight) {
            header
            if vm.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(vm.openItems) { row(for: $0) }
                        if !vm.doneItems.isEmpty {
                            Rectangle()
                                .fill(DesignTokens.separator)
                                .frame(height: 1)
                                .padding(.vertical, DesignTokens.unit)
                            ForEach(vm.doneItems) { row(for: $0) }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: DesignTokens.menuWidth)
        .background(DesignTokens.surface)
        .foregroundStyle(DesignTokens.onSurface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.stackTight) {
            Text("TASKS")
                .font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            TextField("Add a task", text: $draft)
                .textFieldStyle(.plain)
                .font(DesignTokens.bodySm)
                .padding(.horizontal, DesignTokens.stackTight)
                .frame(height: 30)
                .background(DesignTokens.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusControl))
                .onSubmit(submit)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.unit) {
            Text("No tasks yet").font(DesignTokens.bodySm)
            Text("Add one, then tap it to focus on it — completed sessions are counted against it.")
                .font(DesignTokens.bodySm)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(.vertical, DesignTokens.stackTight)
    }

    private func row(for item: TaskItem) -> some View {
        TaskRow(
            item: item,
            isActive: item.id == vm.activeTaskID,
            onToggleDone: { vm.toggleDone(item.id) },
            onActivate: { vm.setActive(item.id == vm.activeTaskID ? nil : item.id) },
            onDelete: { vm.delete(item.id) })
    }

    private func submit() {
        vm.add(draft)
        draft = ""
    }
}
