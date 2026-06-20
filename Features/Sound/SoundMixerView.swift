import SwiftUI
import FocusFlowKit

struct SoundMixerView: View {
    let vm: SoundMixerViewModel
    private let sleepOptions = [15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.elementGap) {
            Text("MIX").font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            ForEach(AmbientSound.all) { sound in
                SoundTile(sound: sound, isOn: vm.isOn(sound.id), volume: vm.volume(for: sound.id),
                          onToggle: { vm.toggle(sound.id) },
                          onVolume: { vm.setVolume($0, for: sound.id) })
            }
            Text("SLEEP TIMER").font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            HStack {
                ForEach(sleepOptions, id: \.self) { m in
                    Button("\(m)m") { vm.startSleepTimer(minutes: m) }.buttonStyle(.bordered)
                }
                Button("Off") { vm.cancelSleepTimer() }.buttonStyle(.bordered)
            }
            if let text = vm.sleepRemainingText {
                Text("Stops all sounds in \(text)").font(DesignTokens.monoLabel)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: DesignTokens.menuWidth)
        .background(DesignTokens.surface).foregroundStyle(DesignTokens.onSurface)
    }
}
