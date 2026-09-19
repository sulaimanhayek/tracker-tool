import AppKit

public enum Chime {
    /// A system sound keeps the app free of bundled audio; silence is acceptable
    /// if the sound is missing, so nothing here can fail loudly.
    public static func play() {
        NSSound(named: "Glass")?.play()
    }
}
