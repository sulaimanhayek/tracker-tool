using Avalonia.Controls;
using Avalonia.Platform.Storage;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Focus.Core;
using CoreBackground = Focus.Core.Background;

namespace Focus.App;

/// Everything adjustable in one place: how long a stretch runs, what the app
/// looks like, and where the files go.
public partial class SettingsWindow : Window
{
    private readonly Shell _shell;

    public SettingsWindow() : this(new Shell()) { }

    public SettingsWindow(Shell shell)
    {
        _shell = shell;
        InitializeComponent();

        BuildDurations();
        BuildSwatches();
        RefreshStorage();

        var sounds = this.FindControl<CheckBox>("SoundsToggle")!;
        sounds.IsChecked = Sounds.IsEnabled;
        sounds.IsCheckedChanged += (_, _) => Sounds.IsEnabled = sounds.IsChecked == true;
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    /// One row per mode: type the number or nudge it. The box keeps its own text
    /// while it is being edited — writing the number back on every keystroke
    /// would rewrite "6" to 6 before "60" is finished — and is read back when
    /// you press Enter or leave the field.
    private void BuildDurations()
    {
        var rows = this.FindControl<StackPanel>("DurationRows")!;

        foreach (var mode in TimerModes.All)
        {
            var current = _shell.Timer.Durations.GetValueOrDefault(mode, mode.DefaultMinutes());

            var box = new NumericUpDown
            {
                Value = current,
                Minimum = 1,
                Maximum = 480,
                Increment = 1,
                FormatString = "0",
                Width = 130,
                ClipValueToMinMax = true
            };
            box.ValueChanged += (_, _) =>
            {
                if (box.Value is null) return;
                _shell.Timer.SetDuration(mode, (int)box.Value.Value);
            };

            var reset = new Button { Content = "Reset", Background = Brushes.Transparent, BorderThickness = default };
            reset.Click += (_, _) =>
            {
                box.Value = mode.DefaultMinutes();
                _shell.Timer.SetDuration(mode, mode.DefaultMinutes());
            };

            rows.Children.Add(new Grid
            {
                ColumnDefinitions = new ColumnDefinitions("120,Auto,Auto,*"),
                Children =
                {
                    Cell(new TextBlock { Text = mode.Label(), VerticalAlignment = VerticalAlignment.Center }, 0),
                    Cell(box, 1),
                    Cell(new TextBlock
                    {
                        Text = "min",
                        Margin = new Avalonia.Thickness(8, 0, 0, 0),
                        VerticalAlignment = VerticalAlignment.Center,
                        Opacity = 0.65
                    }, 2),
                    Cell(reset, 3)
                }
            });
        }
    }

    private static Control Cell(Control control, int column)
    {
        Grid.SetColumn(control, column);
        if (column == 3) control.HorizontalAlignment = HorizontalAlignment.Right;
        return control;
    }

    /// A small picture of each palette rather than a colour name — the point is
    /// how it looks, so show it.
    private void BuildSwatches()
    {
        var swatches = new List<Control>();

        foreach (var background in CoreBackground.All)
        {
            var isSelected = _shell.Backgrounds.Selected == background.Key;

            var preview = new Panel
            {
                Height = 60,
                Children =
                {
                    new Border { Background = Palette.Brush(background.BackgroundHex) },
                    new Border
                    {
                        Background = Palette.Brush(background.SurfaceHex),
                        Height = 22,
                        Margin = new Avalonia.Thickness(8),
                        CornerRadius = new Avalonia.CornerRadius(4),
                        VerticalAlignment = VerticalAlignment.Bottom
                    }
                }
            };

            var label = new Border
            {
                Background = Palette.Brush(background.SurfaceHex),
                Padding = new Avalonia.Thickness(8, 5),
                Child = new TextBlock
                {
                    Text = background.Label,
                    FontSize = 12,
                    Foreground = Palette.Brush(background.TextHex)
                }
            };

            var button = new Button
            {
                Padding = default,
                Margin = new Avalonia.Thickness(0, 0, 10, 10),
                Width = 148,
                BorderThickness = new Avalonia.Thickness(isSelected ? 2.5 : 1),
                BorderBrush = isSelected
                    ? new SolidColorBrush(Color.FromRgb(90, 150, 240))
                    : Palette.Brush(background.BorderHex),
                CornerRadius = new Avalonia.CornerRadius(8),
                Content = new StackPanel { Children = { preview, label } }
            };

            var key = background.Key;
            button.Click += (_, _) =>
            {
                _shell.Backgrounds.Selected = key;
                BuildSwatches(); // redraw so the ring moves to the new choice
            };

            swatches.Add(button);
        }

        this.FindControl<ItemsControl>("Swatches")!.ItemsSource = swatches;
    }

    /// The folder shown as the directory it is, not described.
    private void RefreshStorage()
    {
        this.FindControl<SelectableTextBlock>("FolderPath")!.Text = DataFolder.Path;

        var directory = this.FindControl<StackPanel>("Directory")!;
        directory.Children.Clear();

        var entries = DataFolder.IsChosen ? DataFolder.Listing() : new List<DataFolder.Entry>();
        if (entries.Count == 0)
        {
            directory.Children.Add(new TextBlock
            {
                Text = "Empty for now — the files appear as you use the app.",
                FontSize = 12,
                Opacity = 0.65
            });
            return;
        }

        foreach (var entry in entries)
        {
            directory.Children.Add(Row(entry, 0));
            foreach (var child in entry.Children) directory.Children.Add(Row(child, 1));
        }
    }

    private static Control Row(DataFolder.Entry entry, int indent) => new TextBlock
    {
        Text = (entry.IsDirectory ? "\U0001F4C1  " : "\U0001F4C4  ") + entry.Name,
        FontFamily = new FontFamily("Consolas,Menlo,monospace"),
        FontSize = 12,
        Margin = new Avalonia.Thickness(indent * 18, 0, 0, 0)
    };

    private async void ChangeFolder(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var picked = await StorageProvider.OpenFolderPickerAsync(new Avalonia.Platform.Storage.FolderPickerOpenOptions
        {
            Title = "Choose a folder for your Focus data",
            AllowMultiple = false
        });

        var folder = picked.FirstOrDefault()?.TryGetLocalPath();
        if (string.IsNullOrEmpty(folder)) return;

        _shell.ChangeFolder(folder, this.FindControl<CheckBox>("MoveExisting")!.IsChecked == true);
        RefreshStorage();
    }

    private void Reveal(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => DataFolder.Reveal();

    private void RefreshDirectory(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => RefreshStorage();
}
