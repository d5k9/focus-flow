import AppKit
import FocusFlowKit

/// Plays a completion chime. Honours "Sound Effects"; if the named sound is
/// missing it falls back to the system beep — log and skip, never crash.
final class SystemSoundService: SoundPlaying {
    private let isEnabled: () -> Bool
    private let soundName: String

    init(isEnabled: @escaping () -> Bool, soundName: String = "Glass") {
        self.isEnabled = isEnabled
        self.soundName = soundName
    }

    func playCompletionChime() {
        guard isEnabled() else { return }
        if let sound = NSSound(named: soundName) {
            sound.play()
        } else {
            NSLog("FocusFlow: chime '\(soundName)' missing; using system beep")
            NSSound.beep()
        }
    }
}
