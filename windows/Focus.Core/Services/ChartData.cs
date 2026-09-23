namespace Focus.Core;

/// One theme's share of a period.
public sealed record ThemeSlice(string Theme, int Seconds, int Colour);

/// One bar of the chart, with everything drawing it needs already worked out.
///
/// The labels are formatted here rather than in the view because formatting a
/// date is not free, and the chart would otherwise format two per bar on every
/// redraw — which is what made pointing at the Mac app's chart feel slow.
public sealed record PeriodBreakdown(
    DateTime Start, string Title, string ShortTitle, int Seconds, List<ThemeSlice> Slices);

/// The colours themes are drawn in. Assignment follows the order a theme first
/// appears in the log, so a theme keeps its colour as the log grows and the same
/// file draws the same chart on every one of the three apps.
public static class ChartPalette
{
    public static readonly string[] Colours =
    {
        "#f2766b", "#4aa3df", "#63c39b", "#e2b04a", "#a98bdc", "#ef8fb4",
        "#5bc0c7", "#c4a484", "#8fbf5e", "#e08a4c", "#7f8fd6", "#cf6f9b"
    };

    public static string Colour(int index) =>
        Colours[((index % Colours.Length) + Colours.Length) % Colours.Length];

    /// The themes in the order they first show up, which is the order they are
    /// given colours in.
    public static List<string> Order(IEnumerable<Session> sessions)
    {
        var seen = new HashSet<string>();
        var order = new List<string>();
        foreach (var session in sessions)
        {
            var theme = Statistics.Label(session.Theme);
            if (seen.Add(theme)) order.Add(theme);
        }
        return order;
    }
}

/// How wide a bar is and how far apart bars sit.
///
/// A bar is the same width in every tab — five years otherwise turn into five
/// slabs while fourteen days are thin strips — and the width left over is shared
/// between them, so the chart still spans the window.
public static class ChartLayout
{
    public const double WidestBar = 34;
    public const double TightestGap = 6;

    public static double BarWidth(int count, double chartWidth)
    {
        var columns = Math.Max(count, 1);
        // Each bar carries its own gap, so a cramped chart still fits.
        var room = chartWidth / columns - TightestGap;
        return Math.Max(2, Math.Min(WidestBar, room));
    }

    /// The gap belongs to the column rather than sitting between columns, so the
    /// columns tile the chart and pointing anywhere above a gap still picks the
    /// bar next to it.
    public static double Gap(int count, double chartWidth, double barWidth)
    {
        var columns = Math.Max(count, 1);
        return Math.Max(TightestGap, (chartWidth - barWidth * columns) / columns);
    }
}

/// Where the hover label sits and how tall it is.
///
/// The label is put above the bar it describes rather than over it, so neither
/// the bar nor the pointer is hidden by the thing explaining them.
public static class ChartLabel
{
    /// The gap between the top of the bar and the bottom of the label.
    public const double Clearance = 8;

    /// Worked out rather than measured, because the position is needed in the
    /// same pass that draws the label.
    public static double Height(int rows)
    {
        const double heading = 17;
        const double line = 16;
        // No rows means one line saying there is nothing to show.
        return 16 + heading + (rows == 0 ? line : rows * line + line);
    }

    /// How far down from the top of the chart the label starts. It sits on top
    /// of a tall bar only when there is no room above it.
    public static double Top(double barHeight, double chartHeight, double labelHeight) =>
        Math.Max(0, chartHeight - barHeight - Clearance - labelHeight);

    /// Kept on the chart, whichever bar is pointed at.
    public static double Left(double barCentre, double chartWidth, double labelWidth) =>
        Math.Min(Math.Max(0, barCentre - labelWidth / 2), Math.Max(0, chartWidth - labelWidth));
}
