namespace Focus.Core;

public enum Grain { Day, Week, Month, Year }

public static class Grains
{
    public static readonly Grain[] All = { Grain.Day, Grain.Week, Grain.Month, Grain.Year };

    public static string Label(this Grain grain) => grain switch
    {
        Grain.Day => "Daily",
        Grain.Week => "Weekly",
        Grain.Month => "Monthly",
        _ => "Yearly"
    };

    /// How many periods the chart looks back over.
    public static int Span(this Grain grain) => grain switch
    {
        Grain.Day => 14,
        Grain.Week => 12,
        Grain.Month => 12,
        _ => 5
    };

    public static string Title(this Grain grain, DateTime date) => grain switch
    {
        Grain.Day => date.ToString("ddd d MMM"),
        Grain.Week => "w/c " + date.ToString("d MMM"),
        Grain.Month => date.ToString("MMMM yyyy"),
        _ => date.ToString("yyyy")
    };

    public static string ShortTitle(this Grain grain, DateTime date) => grain switch
    {
        Grain.Day => date.ToString("ddd").Substring(0, 1),
        Grain.Week => date.ToString("d MMM"),
        Grain.Month => date.ToString("MMM"),
        _ => date.ToString("yyyy")
    };
}
