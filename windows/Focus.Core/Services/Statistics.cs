using System.Globalization;

namespace Focus.Core;

public sealed record Bucket(DateTime Start, int Seconds)
{
    public double Hours => Seconds / 3600.0;
}

public sealed record ThemeTotal(string Theme, int Seconds);

/// Every figure the app shows is computed here from the session log. Nothing is
/// cached to disk, so the reports cannot fall out of step with the record.
public static class Statistics
{
    public static DateTime Start(DateTime date, Grain grain) => grain switch
    {
        Grain.Day => date.Date,
        Grain.Week => StartOfWeek(date),
        Grain.Month => new DateTime(date.Year, date.Month, 1),
        _ => new DateTime(date.Year, 1, 1)
    };

    private static DateTime StartOfWeek(DateTime date)
    {
        var first = CultureInfo.CurrentCulture.DateTimeFormat.FirstDayOfWeek;
        var offset = ((int)date.DayOfWeek - (int)first + 7) % 7;
        return date.Date.AddDays(-offset);
    }

    private static DateTime Step(DateTime date, Grain grain, int by) => grain switch
    {
        Grain.Day => date.AddDays(by),
        Grain.Week => date.AddDays(by * 7),
        Grain.Month => date.AddMonths(by),
        _ => date.AddYears(by)
    };

    /// One bucket per period, oldest first, including periods with no sessions
    /// so the gaps in a run of days are visible rather than closed up.
    public static List<Bucket> Buckets(IEnumerable<Session> sessions, Grain grain, DateTime? now = null)
    {
        var current = Start(now ?? DateTime.Now, grain);
        var totals = new Dictionary<DateTime, int>();
        foreach (var session in sessions)
        {
            var bucket = Start(session.Start, grain);
            totals[bucket] = totals.GetValueOrDefault(bucket) + session.Seconds;
        }

        return Enumerable.Range(0, grain.Span())
            .Select(back => Step(current, grain, -(grain.Span() - 1 - back)))
            .Select(start => new Bucket(start, totals.GetValueOrDefault(start)))
            .ToList();
    }

    public static int Total(IEnumerable<Session> sessions, Grain grain, DateTime? now = null)
    {
        var current = Start(now ?? DateTime.Now, grain);
        return sessions.Where(s => Start(s.Start, grain) == current).Sum(s => s.Seconds);
    }

    public static List<ThemeTotal> ByTheme(IEnumerable<Session> sessions, Grain grain, DateTime? now = null)
    {
        var current = Start(now ?? DateTime.Now, grain);
        return sessions
            .Where(s => Start(s.Start, grain) == current)
            .GroupBy(s => Label(s.Theme))
            .Select(group => new ThemeTotal(group.Key, group.Sum(s => s.Seconds)))
            .OrderByDescending(t => t.Seconds)
            .ToList();
    }

    /// A session with no theme still has to be called something.
    public static string Label(string theme) => theme.Length == 0 ? "No theme" : theme;

    /// The whole chart in one pass over the log: a bar per period, each split by
    /// theme, with its labels already formatted.
    public static List<PeriodBreakdown> Breakdown(IEnumerable<Session> sessions, Grain grain, DateTime? now = null)
    {
        var all = sessions as IReadOnlyCollection<Session> ?? sessions.ToList();
        var current = Start(now ?? DateTime.Now, grain);
        var colours = ChartPalette.Order(all);

        var byPeriod = new Dictionary<DateTime, Dictionary<string, int>>();
        foreach (var session in all)
        {
            var period = Start(session.Start, grain);
            if (!byPeriod.TryGetValue(period, out var totals))
                byPeriod[period] = totals = new Dictionary<string, int>();
            var theme = Label(session.Theme);
            totals[theme] = totals.GetValueOrDefault(theme) + session.Seconds;
        }

        return Enumerable.Range(0, grain.Span())
            .Select(back => Step(current, grain, -(grain.Span() - 1 - back)))
            .Select(period =>
            {
                var totals = byPeriod.GetValueOrDefault(period) ?? new Dictionary<string, int>();
                // Slices keep the palette's order rather than the day's, so a
                // theme sits at the same height from one bar to the next.
                var slices = totals
                    .Select(pair => new ThemeSlice(pair.Key, pair.Value, Math.Max(0, colours.IndexOf(pair.Key))))
                    .OrderBy(slice => slice.Colour)
                    .ToList();

                return new PeriodBreakdown(
                    period,
                    grain.Title(period),
                    grain.ShortTitle(period),
                    slices.Sum(slice => slice.Seconds),
                    slices);
            })
            .ToList();
    }

    /// `2:05` — hours and minutes, for the tight rows of the chart label where
    /// every line has to line up.
    public static string Clock(int seconds) => $"{seconds / 3600}:{seconds % 3600 / 60:00}";

    public static string Format(int seconds)
    {
        var hours = seconds / 3600;
        var minutes = seconds % 3600 / 60;
        if (hours == 0) return $"{minutes}m";
        return minutes == 0 ? $"{hours}h" : $"{hours}h {minutes}m";
    }
}
