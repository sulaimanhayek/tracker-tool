namespace Focus.Core;

/// Focus time that happened away from the timer, entered by hand.
///
/// A manual row is an ordinary session — same six columns, same file — because
/// the point of the log is what the day held, not which button recorded it.
public static class ManualEntry
{
    /// The longest stretch that can be entered in one go. Anything longer is far
    /// more likely to be a mistyped time than a day spent at the desk.
    public const int LongestSeconds = 12 * 60 * 60;

    /// Builds the session from the day picked and two clock times. A finish that
    /// falls before the start is read as having crossed midnight, which is how
    /// the log itself reads such a row back.
    public static Session Build(DateTime day, TimeSpan from, TimeSpan to, string theme)
    {
        var start = day.Date + new TimeSpan(from.Hours, from.Minutes, 0);
        var end = day.Date + new TimeSpan(to.Hours, to.Minutes, 0);
        if (end <= start) end = end.AddDays(1);
        return new Session(start, end, theme, true);
    }

    /// What is wrong with the entry, in words the dialog can show, or null if it
    /// can be saved. Time yet to happen is refused: the log is a record, not a
    /// plan.
    public static string? Problem(Session session, DateTime? now = null)
    {
        if (session.Seconds < 60) return "That is less than a minute.";
        if (session.Seconds > LongestSeconds)
            return $"That is longer than {LongestSeconds / 3600} hours — check the times.";
        if (session.End > (now ?? DateTime.Now).AddMinutes(1)) return "That time has not happened yet.";
        return null;
    }

    /// Whether two stretches of time cover any of the same minutes. Overlapping
    /// entries are allowed — they are only worth mentioning, since double
    /// counting an hour is usually a slip rather than a decision.
    public static bool Overlap(Session session, Session other) =>
        session.Start < other.End && other.Start < session.End;

    public static Session? FirstOverlap(Session session, IEnumerable<Session> logged) =>
        logged.FirstOrDefault(other => Overlap(session, other));
}
