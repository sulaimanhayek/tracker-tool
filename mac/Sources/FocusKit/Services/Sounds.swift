import AppKit

/// The app's two sounds: a tick when a stretch starts, a short alarm when one
/// ends.
///
/// Both are system sounds, which keeps the app free of bundled audio and means
/// they already match the Mac they are playing on. A missing sound is silence
/// rather than an error — nothing here is worth interrupting the user for.
public enum Sounds {
    private static let key = "soundsEnabled"

    /// On unless the user has turned it off.
    public static var isEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: key) != nil else { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// One dry tick, to mark the start of a stretch.
    public static func tick() {
        play("Tink")
    }

    /// Three quick strikes: enough to notice from across the room, short enough
    /// not to be an event in itself.
    public static func alarm() {
        for hit in 0..<3 {
            // A sound cannot overlap itself, so each strike is its own instance
            // and they are spaced far enough apart to be heard separately.
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(hit) * 0.42) {
                play("Glass")
            }
        }
    }

    private static func play(_ name: String) {
        guard isEnabled else { return }
        NSSound(named: name)?.play()
    }
}
