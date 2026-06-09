import SwiftUI
import FocusFlowKit

/// Placeholder preferences view. Replaced with full design in Tasks 10–13.
struct PreferencesView: View {
    let settings: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            Text("Preferences")
                .font(.title2.bold())
            Text("Full preferences UI coming in Tasks 10–13.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 320, height: 360)
    }
}
