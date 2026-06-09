/// Plays the completion chime. Concrete implementation uses AppKit/AVFoundation
/// in the app target. Also the seam for the future ambient-sound player.
public protocol SoundPlaying: AnyObject {
    func playCompletionChime()
}
