import SwiftUI
import FocusFlowKit

struct SoundTile: View {
    let sound: AmbientSound
    let isOn: Bool
    let volume: Double
    var onToggle: () -> Void
    var onVolume: (Double) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: sound.symbol)
                Text(sound.name).font(DesignTokens.bodySm)
                Spacer()
                Toggle("", isOn: Binding(get: { isOn }, set: { _ in onToggle() })).labelsHidden()
            }
            Slider(value: Binding(get: { volume }, set: onVolume), in: 0...1)
                .disabled(!isOn)
        }
        .padding(DesignTokens.stackTight)
        .background(isOn ? DesignTokens.surfaceContainerHigh : DesignTokens.surfaceContainerLow,
                    in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sound.name) layer")
    }
}
