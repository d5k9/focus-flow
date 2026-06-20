import AVFoundation
import FocusFlowKit

final class AVAmbientAudioEngine: AmbientAudioEngine {
    private var players: [String: AVAudioPlayer] = [:]

    func play(_ id: String) {
        if let p = players[id] { p.play(); return }
        guard let url = Bundle.main.url(forResource: id, withExtension: "m4a", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: id, withExtension: "m4a") else {
            NSLog("FocusFlow: ambient sound '\(id)' missing; skipping"); return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1; p.prepareToPlay(); p.play()
            players[id] = p
        } catch { NSLog("FocusFlow: failed to load '\(id)': \(error)") }
    }

    func stop(_ id: String) { players[id]?.stop(); players[id] = nil }
    func setVolume(_ volume: Double, for id: String) { players[id]?.volume = Float(volume) }
    func stopAll() { players.values.forEach { $0.stop() }; players.removeAll() }
}
