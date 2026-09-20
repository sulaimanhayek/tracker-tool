namespace Focus.Core;

/// One row of sessions.csv. A session is recorded when focus time ends, whether
/// it ran to completion or was stopped early — an interrupted hour is still an
/// hour.
public sealed record Session(DateTime Start, DateTime End, string Theme, bool Completed)
{
    public int Seconds => Math.Max(0, (int)(End - Start).TotalSeconds);
    public double Minutes => Seconds / 60.0;
}
