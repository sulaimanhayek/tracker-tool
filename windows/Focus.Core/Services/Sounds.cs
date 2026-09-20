namespace Focus.Core;

/// A tick when a stretch starts, a short alarm when one ends. Both are sounds
/// the machine already has, so nothing is bundled and they match whatever the
/// user has set their system to.
public static class Sounds
{
    private const string Key = "soundsEnabled";

    public static bool IsEnabled
    {
        get => Prefs.GetBool(Key, true);
        set => Prefs.Set(Key, value);
    }

    public static void Tick() => Play("Windows Navigation Start.wav", "Tink");

    /// Three strikes rather than one: a single sound is easy to miss from the
    /// other side of a room, and a long alarm is an annoyance.
    public static void Alarm()
    {
        for (var hit = 0; hit < 3; hit++)
        {
            var delay = hit * 420;
            Task.Delay(delay).ContinueWith(_ => Play("Windows Notify.wav", "Glass"));
        }
    }

    private static void Play(string windowsFile, string macName)
    {
        if (!IsEnabled) return;
        try
        {
            if (OperatingSystem.IsWindows())
            {
                var path = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Media", windowsFile);
                if (File.Exists(path)) PlayWindows(path);
                return;
            }

            // Only so the app can be developed and watched on a Mac.
            System.Diagnostics.Process.Start("afplay", $"/System/Library/Sounds/{macName}.aiff");
        }
        catch
        {
            // A sound that will not play is never a reason to stop the timer.
        }
    }

    private static void PlayWindows(string path)
    {
        // Loaded and played on a background thread: a sound must never hold up
        // the tick that started it.
        Task.Run(() =>
        {
            try
            {
                var player = new System.Media.SoundPlayer(path);
                player.PlaySync();
            }
            catch { }
        });
    }
}
