using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using Focus.Core;

namespace Focus.App;

/// Focus time typed in after the fact. The entry is checked as it is typed, so
/// the button says what it will add and is only live when there is something
/// worth adding.
public partial class ManualEntryWindow : Window
{
    private readonly SessionLog _log;
    private readonly ThemeStore _themes;

    public ManualEntryWindow() : this(new SessionLog(), new ThemeStore()) { }

    public ManualEntryWindow(SessionLog log, ThemeStore themes)
    {
        _log = log;
        _themes = themes;
        InitializeComponent();

        var day = this.FindControl<DatePicker>("Day")!;
        var from = this.FindControl<TimePicker>("From")!;
        var to = this.FindControl<TimePicker>("To")!;
        var theme = this.FindControl<ComboBox>("ThemeChoice")!;

        day.SelectedDate = DateTime.Today;
        day.MaxYear = new DateTimeOffset(DateTime.Today.AddYears(1));
        from.SelectedTime = new TimeSpan(9, 0, 0);
        to.SelectedTime = new TimeSpan(10, 0, 0);

        theme.ItemsSource = _themes.Themes.ToList();
        theme.SelectedItem = _themes.Selected ?? _themes.Themes.FirstOrDefault();

        day.SelectedDateChanged += (_, _) => Review();
        from.SelectedTimeChanged += (_, _) => Review();
        to.SelectedTimeChanged += (_, _) => Review();
        theme.SelectionChanged += (_, _) => Review();
        Review();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private Session Entry()
    {
        var day = this.FindControl<DatePicker>("Day")!.SelectedDate?.Date ?? DateTime.Today;
        var from = this.FindControl<TimePicker>("From")!.SelectedTime ?? TimeSpan.Zero;
        var to = this.FindControl<TimePicker>("To")!.SelectedTime ?? TimeSpan.Zero;
        var theme = this.FindControl<ComboBox>("ThemeChoice")!.SelectedItem as string ?? "";
        return ManualEntry.Build(day, from, to, theme);
    }

    private void Review()
    {
        var entry = Entry();
        var problem = ManualEntry.Problem(entry);
        var note = this.FindControl<TextBlock>("Note")!;
        var save = this.FindControl<Button>("Save")!;

        if (problem is not null)
        {
            note.Text = problem;
            save.Content = "Add";
            save.IsEnabled = false;
            return;
        }

        var clash = ManualEntry.FirstOverlap(entry, _log.Sessions);
        var crossesMidnight = entry.End.Date != entry.Start.Date;

        note.Text = $"Adds {Statistics.Format(entry.Seconds)} to {Statistics.Label(entry.Theme)}."
            + (crossesMidnight ? " Runs past midnight into the next day." : "")
            + (clash is not null ? " This overlaps something already logged." : "");
        save.Content = $"Add {Statistics.Format(entry.Seconds)}";
        save.IsEnabled = true;
    }

    private void Add(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var entry = Entry();
        if (ManualEntry.Problem(entry) is not null) return;
        _log.Append(entry);
        Close(true);
    }

    private void Cancel(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(false);
}
