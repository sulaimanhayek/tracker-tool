using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Focus.Core;

namespace Focus.App;

/// Everything here is worked out from sessions.csv when the page is drawn, so
/// no figure on it can disagree with the file.
public partial class StatsView : UserControl
{
    private const double BarArea = 170;
    private const double LabelWidth = 190;

    private readonly Shell _shell;
    private Grain _grain = Grain.Day;

    // The chart is worked out once per change and kept, so pointing along the
    // bars costs a lookup rather than another walk through the whole log.
    private List<PeriodBreakdown> _periods = new();
    private readonly List<Border> _bars = new();
    private Border? _label;
    private int _hovered = -1;
    private double _column;

    public StatsView() : this(new Shell()) { }

    public StatsView(Shell shell)
    {
        _shell = shell;
        InitializeComponent();

        shell.Log.Sessions.CollectionChanged += (_, _) => Refresh();

        var chart = this.FindControl<Canvas>("Chart")!;
        chart.SizeChanged += (_, _) => DrawChart();
        chart.PointerMoved += OnPointerMoved;
        chart.PointerExited += (_, _) => Highlight(-1);

        Refresh();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private static IBrush Brush(string hex)
    {
        var (r, g, b) = global::Focus.Core.Background.Rgb(hex);
        return new SolidColorBrush(Color.FromRgb(r, g, b));
    }

    private void Refresh()
    {
        BuildGrainPicker();

        var sessions = _shell.Log.Sessions;
        var total = Statistics.Total(sessions, _grain);

        this.FindControl<TextBlock>("TotalValue")!.Text = Statistics.Format(total);
        this.FindControl<TextBlock>("TotalCaption")!.Text = _grain switch
        {
            Grain.Day => "focused today",
            Grain.Week => "focused this week",
            Grain.Month => "focused this month",
            _ => "focused this year"
        };

        _periods = Statistics.Breakdown(sessions, _grain);
        DrawChart();
        BuildLegend();
        BuildThemes(Statistics.ByTheme(sessions, _grain), ChartPalette.Order(sessions));

        this.FindControl<TextBlock>("Footnote")!.Text =
            $"{sessions.Count} session{(sessions.Count == 1 ? "" : "s")} on record in {DataFolder.SessionsFile}.";
    }

    private void BuildGrainPicker()
    {
        var buttons = new List<Control>();
        foreach (var grain in global::Focus.Core.Grains.All)
        {
            var value = grain;
            var button = new Button
            {
                Content = grain.Label(),
                Margin = new Thickness(0, 0, 8, 0),
                Classes = { "page" }
            };
            button.Classes.Set("selected", grain == _grain);
            button.Click += (_, _) => { _grain = value; Refresh(); };
            buttons.Add(button);
        }
        this.FindControl<ItemsControl>("GrainTabs")!.ItemsSource = buttons;
    }

    /// A bar per period, each split by theme and stacked in the palette's order,
    /// so a theme sits at the same height from one bar to the next. Bars keep one
    /// width whatever the period is; the width left over goes into the gaps.
    private void DrawChart()
    {
        var chart = this.FindControl<Canvas>("Chart")!;
        chart.Children.Clear();
        _bars.Clear();
        _label = null;
        _hovered = -1;

        var width = chart.Bounds.Width;
        if (width <= 0 || _periods.Count == 0) return;

        var barWidth = ChartLayout.BarWidth(_periods.Count, width);
        _column = barWidth + ChartLayout.Gap(_periods.Count, width, barWidth);
        var tallest = Math.Max(1, _periods.Max(period => period.Seconds));

        for (var index = 0; index < _periods.Count; index++)
        {
            var period = _periods[index];
            var height = Math.Max(2, BarArea * period.Seconds / tallest);

            var stack = new StackPanel { Width = barWidth };
            if (period.Slices.Count == 0)
            {
                stack.Children.Add(new Border { Height = height, Background = Brush("#808080"), Opacity = 0.25 });
            }
            else
            {
                // Added top down, so the first colour of the palette is the one
                // sitting on the baseline.
                foreach (var slice in Enumerable.Reverse(period.Slices))
                    stack.Children.Add(new Border
                    {
                        Height = Math.Max(1, BarArea * slice.Seconds / tallest),
                        Background = Brush(ChartPalette.Colour(slice.Colour))
                    });
            }

            var bar = new Border
            {
                Width = barWidth,
                Height = height,
                CornerRadius = new CornerRadius(3, 3, 2, 2),
                ClipToBounds = true,
                Child = stack
            };
            Canvas.SetLeft(bar, index * _column + (_column - barWidth) / 2);
            Canvas.SetTop(bar, BarArea - height);
            chart.Children.Add(bar);
            _bars.Add(bar);

            var tick = new TextBlock
            {
                Text = period.ShortTitle,
                FontSize = 10,
                Opacity = 0.6,
                Width = _column,
                TextAlignment = TextAlignment.Center
            };
            Canvas.SetLeft(tick, index * _column);
            Canvas.SetTop(tick, BarArea + 6);
            chart.Children.Add(tick);
        }
    }

    private void OnPointerMoved(object? sender, PointerEventArgs e)
    {
        if (_column <= 0 || _periods.Count == 0) return;
        var x = e.GetPosition((Visual)sender!).X;
        // The gap belongs to the column, so pointing at the space beside a bar
        // still picks that bar.
        var index = Math.Clamp((int)(x / _column), 0, _periods.Count - 1);
        Highlight(index);
    }

    private void Highlight(int index)
    {
        if (index == _hovered) return;
        _hovered = index;

        var chart = this.FindControl<Canvas>("Chart")!;
        if (_label is not null) chart.Children.Remove(_label);
        _label = null;

        for (var at = 0; at < _bars.Count; at++)
            _bars[at].Opacity = index < 0 || at == index ? 1 : 0.5;

        if (index < 0) return;

        var period = _periods[index];
        _label = BuildLabel(period);
        var height = ChartLabel.Height(period.Slices.Count);
        var barHeight = Math.Max(2, BarArea * period.Seconds / Math.Max(1, _periods.Max(p => p.Seconds)));

        Canvas.SetLeft(_label, ChartLabel.Left(_column * (index + 0.5), chart.Bounds.Width, LabelWidth));
        Canvas.SetTop(_label, ChartLabel.Top(barHeight, BarArea, height));
        chart.Children.Add(_label);
    }

    /// The period, what it was made of, and the total — half see-through, and
    /// above the bar rather than over it, so neither the bar nor the pointer is
    /// hidden by the thing explaining them.
    private static Border BuildLabel(PeriodBreakdown period)
    {
        var rows = new StackPanel();
        rows.Children.Add(new TextBlock
        {
            Text = period.Title,
            FontSize = 12,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brushes.White,
            Margin = new Thickness(0, 0, 0, 3)
        });

        if (period.Slices.Count == 0)
        {
            rows.Children.Add(new TextBlock
            {
                Text = "Nothing logged",
                FontSize = 11,
                Foreground = Brushes.White,
                Opacity = 0.8
            });
        }
        else
        {
            foreach (var slice in period.Slices)
                rows.Children.Add(new Grid
                {
                    ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"),
                    Height = 16,
                    Children =
                    {
                        new Border
                        {
                            Width = 8,
                            Height = 8,
                            CornerRadius = new CornerRadius(2),
                            Background = Brush(ChartPalette.Colour(slice.Colour)),
                            VerticalAlignment = VerticalAlignment.Center,
                            Margin = new Thickness(0, 0, 6, 0)
                        },
                        At(1, new TextBlock
                        {
                            Text = slice.Theme,
                            FontSize = 11,
                            Foreground = Brushes.White,
                            TextTrimming = TextTrimming.CharacterEllipsis
                        }),
                        At(2, new TextBlock
                        {
                            Text = Statistics.Clock(slice.Seconds),
                            FontSize = 11,
                            Foreground = Brushes.White,
                            Margin = new Thickness(8, 0, 0, 0)
                        })
                    }
                });

            rows.Children.Add(new TextBlock
            {
                Text = $"TOTAL: {Statistics.Clock(period.Seconds)}",
                FontSize = 11,
                FontWeight = FontWeight.SemiBold,
                Foreground = Brushes.White,
                Margin = new Thickness(0, 3, 0, 0)
            });
        }

        return new Border
        {
            Width = LabelWidth,
            Padding = new Thickness(8),
            CornerRadius = new CornerRadius(6),
            Background = new SolidColorBrush(Colors.Black, 0.5),
            // The label explains the chart; it must never intercept the pointer
            // that is asking the question.
            IsHitTestVisible = false,
            Child = rows
        };
    }

    private static Control At(int column, Control control)
    {
        Grid.SetColumn(control, column);
        return control;
    }

    /// Which theme wears which colour, said once rather than on every bar.
    private void BuildLegend()
    {
        var seen = new List<ThemeSlice>();
        foreach (var period in _periods)
            foreach (var slice in period.Slices)
                if (!seen.Any(other => other.Theme == slice.Theme)) seen.Add(slice);

        this.FindControl<ItemsControl>("Legend")!.ItemsSource = seen
            .OrderBy(slice => slice.Colour)
            .Select(slice => new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 6,
                Margin = new Thickness(0, 0, 16, 4),
                Children =
                {
                    new Border
                    {
                        Width = 9,
                        Height = 9,
                        CornerRadius = new CornerRadius(2),
                        Background = Brush(ChartPalette.Colour(slice.Colour)),
                        VerticalAlignment = VerticalAlignment.Center
                    },
                    new TextBlock { Text = slice.Theme, FontSize = 12, Opacity = 0.75 }
                }
            })
            .ToList();
    }

    private void BuildThemes(List<ThemeTotal> totals, List<string> order)
    {
        var host = this.FindControl<StackPanel>("Themes")!;
        host.Children.Clear();

        if (totals.Count == 0)
        {
            host.Children.Add(new TextBlock
            {
                Text = "Nothing logged for this period yet.",
                Classes = { "caption" }
            });
            return;
        }

        var largest = totals[0].Seconds;
        foreach (var total in totals)
        {
            var share = largest == 0 ? 0 : (double)total.Seconds / largest;

            host.Children.Add(new StackPanel
            {
                Spacing = 4,
                Children =
                {
                    new Grid
                    {
                        ColumnDefinitions = new ColumnDefinitions("*,Auto"),
                        Children =
                        {
                            new TextBlock { Text = total.Theme },
                            At(1, new TextBlock { Text = Statistics.Format(total.Seconds), Opacity = 0.7 })
                        }
                    },
                    new ProgressBar
                    {
                        Minimum = 0,
                        Maximum = 1,
                        Value = share,
                        Height = 6,
                        // The same colour the theme wears in the chart above.
                        Foreground = Brush(ChartPalette.Colour(Math.Max(0, order.IndexOf(total.Theme))))
                    }
                }
            });
        }
    }

    private async void AddTime(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (TopLevel.GetTopLevel(this) is not Window owner) return;
        await new ManualEntryWindow(_shell.Log, _shell.Themes).ShowDialog<bool>(owner);
    }
}
