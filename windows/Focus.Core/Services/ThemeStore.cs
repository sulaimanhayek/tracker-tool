using System.Collections.ObjectModel;
using System.Text.Json;

namespace Focus.Core;

/// The list of themes, kept in themes.json. Only the names live here — every
/// total is derived from the session log, so the two files cannot disagree.
public sealed class ThemeStore : Observable
{
    private string? _selected;

    public ObservableCollection<string> Themes { get; } = new();

    public string? Selected
    {
        get => _selected;
        set { if (Set(ref _selected, value)) Prefs.Set("selectedTheme", value); }
    }

    public ThemeStore()
    {
        _selected = Prefs.GetString("selectedTheme");
        Load();
    }

    public void Load()
    {
        try
        {
            var saved = JsonSerializer.Deserialize<List<string>>(File.ReadAllText(DataFolder.ThemesFile));
            if (saved is null) return;
            Themes.Clear();
            foreach (var theme in saved) Themes.Add(theme);
            Raise(nameof(Themes));
            if (_selected is not null && !Themes.Contains(_selected)) Selected = null;
        }
        catch { }
    }

    public void Add(string name)
    {
        var trimmed = name.Trim();
        if (trimmed.Length == 0 || Themes.Contains(trimmed)) return;
        Themes.Add(trimmed);
        Save();
        if (Selected is null) Selected = trimmed;
    }

    public void Remove(string name)
    {
        if (!Themes.Remove(name)) return;
        Save();
        if (Selected == name) Selected = null;
    }

    private void Save()
    {
        try
        {
            DataFolder.EnsureExists();
            File.WriteAllText(DataFolder.ThemesFile, JsonSerializer.Serialize(Themes.ToList()));
        }
        catch { }
    }
}
