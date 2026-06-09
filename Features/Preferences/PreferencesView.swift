import SwiftUI
import FocusFlowKit

struct PreferencesView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.elementGap) {
            Text("FocusFlow").font(DesignTokens.headlineMd)

            section("TIMER DURATIONS") {
                durationRow("Focus", value: $settings.focusMinutes, range: 1...120)
                separator
                durationRow("Short Break", value: $settings.shortBreakMinutes, range: 1...60)
                separator
                durationRow("Long Break", value: $settings.longBreakMinutes, range: 1...60)
            }

            section("NOTIFICATIONS") {
                Toggle("Sound Effects", isOn: $settings.soundEffectsEnabled)
                separator
                Toggle("Desktop Alerts", isOn: $settings.desktopAlertsEnabled)
            }
            .toggleStyle(.switch)
            .tint(DesignTokens.focusRed)

            section("APPEARANCE") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
        .font(DesignTokens.bodySm)
        .padding(DesignTokens.containerPadding)
        .frame(width: 320, alignment: .leading)
        .background(DesignTokens.surface)
        .foregroundStyle(DesignTokens.onSurface)
    }

    private var separator: some View {
        Rectangle().fill(DesignTokens.separator).frame(height: 1)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.stackTight) {
            Text(title)
                .font(DesignTokens.labelCaps)
                .tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            VStack(spacing: DesignTokens.stackTight) { content() }
        }
    }

    private func durationRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)").monospacedDigit()
            }
            .labelsHidden()
            Text("\(value.wrappedValue)").monospacedDigit().frame(minWidth: 28, alignment: .trailing)
            Text("MIN").font(DesignTokens.monoLabel).foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(minHeight: DesignTokens.rowMinHeight)
    }
}
