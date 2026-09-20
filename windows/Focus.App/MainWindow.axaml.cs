using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Avalonia.Styling;
using Focus.Core;

namespace Focus.App;

public partial class MainWindow : Window
{
    private readonly Shell _shell;
    private readonly TimerView _timer;
    private readonly NotesView _notes;
    private readonly StatsView _stats;

    public MainWindow() : this(new Shell()) { }

    public MainWindow(Shell shell)
    {
        _shell = shell;
        InitializeComponent();

        _timer = new TimerView(shell);
        _notes = new NotesView(shell);
        _stats = new StatsView(shell);

        ShowPage("timer");
        ApplyBackground();

        shell.Backgrounds.PropertyChanged += (_, _) => ApplyBackground();
        shell.Log.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(SessionLog.LastError)) ShowError(); };
        shell.Notes.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(NotesStore.LastError)) ShowError(); };

        Opened += async (_, _) =>
        {
            // Asked once, on the very first run; the answer can be changed later
            // from Settings.
            if (DataFolder.IsChosen) return;
            var chosen = await new WelcomeWindow().ShowDialog<(string Path, bool Move)?>(this);
            if (chosen is null) return;
            shell.ChangeFolder(chosen.Value.Path, chosen.Value.Move);
        };
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private void ShowTimer(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowPage("timer");
    private void ShowNotes(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowPage("notes");
    private void ShowStats(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowPage("stats");

    private void ShowPage(string page)
    {
        _shell.Page = page;
        // Leaving the notes page is a good moment to make sure it is on disk.
        if (page != "notes") _shell.Notes.Flush();
        if (page == "stats") _shell.Log.Load();

        this.FindControl<ContentControl>("PageHost")!.Content = page switch
        {
            "notes" => _notes,
            "stats" => _stats,
            _ => _timer
        };

        foreach (var (name, key) in new[] { ("TimerTab", "timer"), ("NotesTab", "notes"), ("StatsTab", "stats") })
        {
            var button = this.FindControl<Button>(name)!;
            button.Classes.Set("selected", key == page);
        }
    }

    private async void OpenSettings(object? sender, Avalonia.Interactivity.RoutedEventArgs e) =>
        await new SettingsWindow(_shell).ShowDialog(this);

    /// One palette for the whole window: the hue behind everything, and the
    /// light or dark variant it belongs to, so the controls match it.
    private void ApplyBackground()
    {
        var palette = _shell.Backgrounds.Current;
        RequestedThemeVariant = palette.IsDark ? ThemeVariant.Dark : ThemeVariant.Light;
        Background = Palette.Brush(palette.BackgroundHex);
        this.FindControl<Border>("HeaderBar")!.Background = Palette.Brush(palette.SurfaceHex);
        _notes.ApplyBackground();
    }

    private void ShowError()
    {
        var message = _shell.Log.LastError ?? _shell.Notes.LastError;
        this.FindControl<TextBlock>("ErrorText")!.Text = message ?? "";
        this.FindControl<Border>("ErrorBar")!.IsVisible = message is not null;
    }
}

/// Turns the palette's hex into brushes, cached so a redraw is not a parse.
public static class Palette
{
    private static readonly Dictionary<string, IBrush> Cache = new();

    public static IBrush Brush(string hex)
    {
        if (Cache.TryGetValue(hex, out var brush)) return brush;
        var (r, g, b) = Background.Rgb(hex);
        brush = new SolidColorBrush(Color.FromRgb(r, g, b));
        Cache[hex] = brush;
        return brush;
    }
}
