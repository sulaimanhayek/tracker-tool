using System.Globalization;

namespace Focus.Core;

/// A background theme, carrying the whole palette rather than just a colour, so
/// a light background still reads. The same six the web and Mac apps offer.
public sealed record Background(
    string Key, string Label, bool IsDark,
    string BackgroundHex, string SurfaceHex, string BorderHex, string TextHex, string MutedHex)
{
    public static readonly Background[] All =
    {
        new("midnight", "Midnight", true, "#12141a", "#1a1d26", "#272b38", "#e8eaf0", "#8b90a3"),
        new("ink", "Ink", true, "#07080b", "#111318", "#1f2229", "#e6e8ee", "#808493"),
        new("slate", "Slate", true, "#1b2029", "#242a35", "#333b49", "#e9edf4", "#929aac"),
        new("forest", "Forest", true, "#0f1a15", "#17241e", "#24352c", "#e6f0e9", "#879a90"),
        new("paper", "Paper", false, "#f2f3f7", "#ffffff", "#dcdfe8", "#1d2028", "#666c7d"),
        new("parchment", "Parchment", false, "#f5f0e4", "#fffcf3", "#e3dac5", "#2b2618", "#6f6853")
    };

    public static Background Named(string? key) =>
        All.FirstOrDefault(b => b.Key == key) ?? All[0];

    /// `#12141a` to bytes. A malformed value is black rather than a crash — a
    /// theme is decoration, and nothing here is worth stopping for.
    public static (byte R, byte G, byte B) Rgb(string hex)
    {
        var digits = hex.StartsWith("#") ? hex[1..] : hex;
        if (digits.Length != 6 || !int.TryParse(digits, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var value))
            return (0, 0, 0);
        return ((byte)((value >> 16) & 0xff), (byte)((value >> 8) & 0xff), (byte)(value & 0xff));
    }
}

/// Which background the app is wearing, remembered between launches.
public sealed class BackgroundStore : Observable
{
    private const string Key = "background";
    private string _selected;

    public BackgroundStore() => _selected = Prefs.GetString(Key) ?? Background.All[0].Key;

    public string Selected
    {
        get => _selected;
        set
        {
            if (!Set(ref _selected, value)) return;
            Prefs.Set(Key, value);
            Raise(nameof(Current));
        }
    }

    public Background Current => Background.Named(_selected);
}
