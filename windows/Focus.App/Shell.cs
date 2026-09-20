using Avalonia.Threading;
using Focus.Core;

namespace Focus.App;

/// Everything the windows share: the stores, the timer, and the one place that
/// re-points the app at another folder.
public sealed class Shell : Observable
{
    private string _page = "timer";

    public SessionLog Log { get; }
    public ThemeStore Themes { get; }
    public TimerModel Timer { get; }
    public NotesStore Notes { get; }
    public BackgroundStore Backgrounds { get; }

    public string Page
    {
        get => _page;
        set
        {
            if (!Set(ref _page, value)) return;
            Raise(nameof(IsTimer));
            Raise(nameof(IsNotes));
            Raise(nameof(IsStats));
        }
    }

    public bool IsTimer => _page == "timer";
    public bool IsNotes => _page == "notes";
    public bool IsStats => _page == "stats";

    public Shell()
    {
        Log = new SessionLog();
        Themes = new ThemeStore();
        Timer = new TimerModel(Log, Themes);
        Notes = new NotesStore();
        Backgrounds = new BackgroundStore();

        // The view drives the clock: four times a second is enough for a smooth
        // second hand, and the time left is read off the deadline anyway.
        var ticker = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        ticker.Tick += (_, _) => { if (Timer.IsRunning) Timer.Tick(); };
        ticker.Start();
    }

    /// Points the app at another folder and re-reads everything from there.
    public void ChangeFolder(string path, bool movingExisting)
    {
        Notes.Flush();
        try
        {
            DataFolder.Relocate(path, movingExisting);
        }
        catch (Exception error)
        {
            Log.Report($"Could not use that folder: {error.Message}");
            return;
        }

        Log.Load();
        Themes.Load();
        Notes.Reload();
        Raise(nameof(Log));
    }
}
