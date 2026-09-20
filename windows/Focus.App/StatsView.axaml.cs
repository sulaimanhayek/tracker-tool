using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Focus.Core;

namespace Focus.App;

/// Everything here is worked out from sessions.csv when the page is drawn, so
/// no figure on it can disagree with the file.
public partial class StatsView : UserControl
{
    private readonly Shell _shell;
    private Grain _grain = Grain.Day;

    public StatsView() : this(new Shell()) { }

    public StatsView(Shell shell)
    {
        _shell = shell;
        InitializeComponent();

        shell.Log.Sessions.CollectionChanged += (_, _) => Refresh();
        Refresh();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private static readonly IBrush Bar = new SolidColorBrush(Color.FromRgb(242, 110, 92));

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

        BuildChart(Statistics.Buckets(sessions, _grain));
        BuildThemes(Statistics.ByTheme(sessions, _grain), total);

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
                Margin = new Avalonia.Thickness(0, 0, 8, 0),
                Classes = { "page" }
            };
            button.Classes.Set("selected", grain == _grain);
            button.Click += (_, _) => { _grain = value; Refresh(); };
            buttons.Add(button);
        }
        this.FindControl<ItemsControl>("GrainTabs")!.ItemsSource = buttons;
    }

    /// A column per period, scaled to the tallest one. An empty stretch is still
    /// given a sliver so the period is visibly there rather than missing.
    private void BuildChart(List<Bucket> buckets)
    {
        var chart = this.FindControl<Grid>("Chart")!;
        var labels = this.FindControl<Grid>("ChartLabels")!;
        chart.Children.Clear();
        labels.Children.Clear();

        var columns = new ColumnDefinitions(string.Join(",", Enumerable.Repeat("*", Math.Max(buckets.Count, 1))));
        chart.ColumnDefinitions = columns;
        labels.ColumnDefinitions = new ColumnDefinitions(string.Join(",", Enumerable.Repeat("*", Math.Max(buckets.Count, 1))));

        var tallest = buckets.Count == 0 ? 0 : buckets.Max(b => b.Seconds);

        for (var index = 0; index < buckets.Count; index++)
        {
            var bucket = buckets[index];
            var fraction = tallest == 0 ? 0 : (double)bucket.Seconds / tallest;

            var bar = new Border
            {
                Background = Bar,
                Opacity = bucket.Seconds == 0 ? 0.18 : 0.55 + 0.45 * fraction,
                CornerRadius = new Avalonia.CornerRadius(4, 4, 2, 2),
                Margin = new Avalonia.Thickness(3, 0),
                MinHeight = 3,
                Height = Math.Max(3, fraction * 170),
                VerticalAlignment = VerticalAlignment.Bottom
            };
            ToolTip.SetTip(bar, $"{_grain.Title(bucket.Start)} — {Statistics.Format(bucket.Seconds)}");
            Grid.SetColumn(bar, index);
            chart.Children.Add(bar);

            var label = new TextBlock
            {
                Text = _grain.ShortTitle(bucket.Start),
                FontSize = 10,
                Opacity = 0.6,
                HorizontalAlignment = HorizontalAlignment.Center
            };
            Grid.SetColumn(label, index);
            labels.Children.Add(label);
        }
    }

    private void BuildThemes(List<ThemeTotal> totals, int overall)
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

        foreach (var total in totals)
        {
            var share = overall == 0 ? 0 : (double)total.Seconds / overall;

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
                            Right(new TextBlock { Text = Statistics.Format(total.Seconds), Opacity = 0.7 })
                        }
                    },
                    new ProgressBar { Minimum = 0, Maximum = 1, Value = share, Height = 6, Foreground = Bar }
                }
            });
        }
    }

    private static Control Right(Control control)
    {
        Grid.SetColumn(control, 1);
        return control;
    }
}
