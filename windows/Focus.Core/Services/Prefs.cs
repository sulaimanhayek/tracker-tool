using System.Text.Json;

namespace Focus.Core;

/// The Windows stand-in for UserDefaults: one small JSON file in
/// %APPDATA%\Focus. Preferences are not data — the data is the folder the user
/// picked — so these stay with the machine and are never written into it.
public static class Prefs
{
    private static readonly string File = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Focus", "settings.json");

    private static Dictionary<string, JsonElement> _values = Load();

    private static Dictionary<string, JsonElement> Load()
    {
        try
        {
            var text = System.IO.File.ReadAllText(File);
            return JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(text) ?? new();
        }
        catch
        {
            // No file yet, or one we cannot read: defaults all round rather than
            // a failure to start.
            return new();
        }
    }

    /// Used by the checks so a run cannot inherit the last one's state.
    public static void Reset()
    {
        _values = new();
        Save();
    }

    public static string? GetString(string key) =>
        _values.TryGetValue(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    public static int GetInt(string key, int fallback = 0) =>
        _values.TryGetValue(key, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetInt32() : fallback;

    public static bool GetBool(string key, bool fallback = false) =>
        _values.TryGetValue(key, out var v) && (v.ValueKind == JsonValueKind.True || v.ValueKind == JsonValueKind.False)
            ? v.GetBoolean() : fallback;

    public static void Set(string key, string? value)
    {
        if (value is null) _values.Remove(key);
        else _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public static void Set(string key, int value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public static void Set(string key, bool value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public static void Remove(string key)
    {
        _values.Remove(key);
        Save();
    }

    private static void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(File)!);
            System.IO.File.WriteAllText(File, JsonSerializer.Serialize(_values,
                new JsonSerializerOptions { WriteIndented = true }));
        }
        catch
        {
            // A preference that will not save is not worth taking the app down for.
        }
    }
}
