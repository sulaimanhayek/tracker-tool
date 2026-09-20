using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Focus.Core;

namespace Focus.App;

public partial class TimerView : UserControl
{
    private readonly Shell _shell;

    public TimerView() : this(new Shell()) { }

    public TimerView(Shell shell)
    {
        _shell = shell;
        InitializeComponent();

        shell.Timer.PropertyChanged += (_, _) => Refresh();
        shell.Themes.PropertyChanged += (_, _) => Refresh();
        shell.Themes.Themes.CollectionChanged += (_, _) => Refresh();
        Refresh();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    /// The mode's colour: warm for focus, cool for the two kinds of break, so
    /// which one you are in is clear at a glance from across a desk.
    private static IBrush Tint(TimerMode mode) => mode switch
    {
        TimerMode.Focus => new SolidColorBrush(Color.FromRgb(242, 110, 92)),
        TimerMode.ShortBreak => new SolidColorBrush(Color.FromRgb(79, 199, 153)),
        _ => new SolidColorBrush(Color.FromRgb(92, 158, 242))
    };

    private void Refresh()
    {
        var timer = _shell.Timer;

        this.FindControl<TextBlock>("Clock")!.Text = ClockText(timer.Remaining);
        this.FindControl<TextBlock>("ThemeLabel")!.Text = _shell.Themes.Selected ?? "No theme selected";
        this.FindControl<Button>("StartButton")!.Content = timer.IsRunning ? "Pause" : "Start";
        this.FindControl<Button>("ResetButton")!.IsEnabled = timer.IsRunning || timer.Remaining < timer.Total;

        var ring = this.FindControl<Arc>("Ring")!;
        ring.Stroke = Tint(timer.Mode);
        ring.SweepAngle = -360 * Math.Clamp(timer.Progress, 0, 1);

        var minutes = timer.Durations.GetValueOrDefault(timer.Mode, timer.Mode.DefaultMinutes());
        this.FindControl<TextBlock>("DurationText")!.Text =
            $"{minutes} min per {timer.Mode.Label().ToLowerInvariant()} — change…";

        foreach (var (name, mode) in new[]
                 {
                     ("FocusTab", TimerMode.Focus),
                     ("ShortTab", TimerMode.ShortBreak),
                     ("LongTab", TimerMode.LongBreak)
                 })
        {
            this.FindControl<Button>(name)!.Classes.Set("selected", timer.Mode == mode);
        }

        RefreshThemes();
    }

    private static string ClockText(double remaining)
    {
        var seconds = (int)Math.Round(remaining);
        var hours = seconds / 3600;
        var minutes = seconds % 3600 / 60;
        var rest = seconds % 60;
        return hours > 0 ? $"{hours}:{minutes:00}:{rest:00}" : $"{minutes:00}:{rest:00}";
    }

    /// A wrapping row of themes; the selected one is what the session log
    /// records against.
    private void RefreshThemes()
    {
        var list = this.FindControl<ItemsControl>("ThemeList")!;
        this.FindControl<TextBlock>("NoThemes")!.IsVisible = _shell.Themes.Themes.Count == 0;

        var chips = new List<Control>();
        foreach (var theme in _shell.Themes.Themes)
        {
            var name = theme;
            var selected = _shell.Themes.Selected == name;

            var remove = new Button
            {
                Content = "✕",
                FontSize = 9,
                Padding = new Avalonia.Thickness(4, 0),
                Background = Brushes.Transparent,
                BorderThickness = default,
                VerticalAlignment = VerticalAlignment.Center
            };
            remove.Click += (_, _) => _shell.Themes.Remove(name);

            var label = new TextBlock { Text = name, VerticalAlignment = VerticalAlignment.Center };
            var chip = new Button
            {
                Margin = new Avalonia.Thickness(0, 0, 8, 8),
                Padding = new Avalonia.Thickness(10, 5),
                Background = selected ? Tint(_shell.Timer.Mode) : Brushes.Transparent,
                Foreground = selected ? Brushes.White : null,
                BorderBrush = new SolidColorBrush(Color.FromArgb(70, 128, 128, 128)),
                BorderThickness = new Avalonia.Thickness(1),
                Content = new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 6,
                    Children = { label, remove }
                }
            };
            chip.Click += (_, _) => _shell.Themes.Selected = selected ? null : name;
            chips.Add(chip);
        }

        list.ItemsSource = chips;
    }

    private void PickFocus(object? s, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Timer.Select(TimerMode.Focus);
    private void PickShort(object? s, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Timer.Select(TimerMode.ShortBreak);
    private void PickLong(object? s, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Timer.Select(TimerMode.LongBreak);
    private void Toggle(object? s, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Timer.Toggle();
    private void Reset(object? s, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Timer.Reset();

    private void AddTheme(object? s, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var box = this.FindControl<TextBox>("NewTheme")!;
        _shell.Themes.Add(box.Text ?? "");
        box.Text = "";
    }

    private void ThemeKey(object? s, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) AddTheme(s, new Avalonia.Interactivity.RoutedEventArgs());
    }

    private async void OpenSettings(object? s, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (TopLevel.GetTopLevel(this) is Window window)
            await new SettingsWindow(_shell).ShowDialog(window);
    }
}
