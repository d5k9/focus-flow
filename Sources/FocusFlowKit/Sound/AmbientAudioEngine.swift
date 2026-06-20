/// Controls looping ambient audio layers. The concrete AVFoundation impl
/// lives in the app target; the mixer view model sees only this protocol.
public protocol AmbientAudioEngine: AnyObject {
    func play(_ id: String)
    func stop(_ id: String)
    func setVolume(_ volume: Double, for id: String)   // 0.0...1.0
    func stopAll()
}
