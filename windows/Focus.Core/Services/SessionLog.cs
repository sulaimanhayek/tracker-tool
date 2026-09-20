using System.Collections.ObjectModel;
using System.Globalization;

namespace Focus.Core;

/// The session log: append-only, one row per finished focus session.
///
/// Nothing here ever rewrites an existing row. Totals by day, week, month and
/// year are computed from this file rather than stored alongside it, so the
/// numbers can never drift from the record and a crash can cost at most the row
/// being written.
public sealed class SessionLog : Observable
{
    public const string Header = "date,start,end,minutes,theme,completed";

    private string? _lastError;

    public ObservableCollection<Session> Sessions { get; } = new();

    public string? LastError { get => _lastError; private set => Set(ref _lastError, value); }

    public SessionLog() => Load();

    /// Surfaces a problem that happened outside the log itself, so the app has
    /// one place to show errors.
    public void Report(string? message) => LastError = message;

    public void Load()
    {
        Sessions.Clear();
        string text;
        try { text = File.ReadAllText(DataFolder.SessionsFile); }
        catch { Raise(nameof(Sessions)); return; }

        foreach (var line in text.Split('\n').Skip(1))
        {
            if (line.Trim().Length == 0) continue;
            var session = Parse(line.TrimEnd('\r'));
            if (session is not null) Sessions.Add(session);
        }
        Raise(nameof(Sessions));
    }

    private static Session? Parse(string row)
    {
        var fields = Csv.Parse(row);
        if (fields.Count < 6) return null;
        if (!TryDate(fields[0], fields[1], out var start)) return null;

        // The end time can fall past midnight; a session is dated by when it began.
        if (!TryDate(fields[0], fields[2], out var end)) end = start;
        if (end < start) end = end.AddDays(1);

        return new Session(start, end, fields[4], fields[5] == "yes");
    }

    private static bool TryDate(string day, string time, out DateTime value) =>
        DateTime.TryParseExact($"{day} {time}", "yyyy-MM-dd HH:mm:ss",
            CultureInfo.InvariantCulture, DateTimeStyles.None, out value);

    /// Appends one row. The file is opened, extended and closed on each call, so
    /// an external edit between sessions is picked up rather than overwritten.
    public void Append(Session session)
    {
        if (session.Seconds <= 0) return;

        var row = Csv.Row(new[]
        {
            session.Start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            session.Start.ToString("HH:mm:ss", CultureInfo.InvariantCulture),
            session.End.ToString("HH:mm:ss", CultureInfo.InvariantCulture),
            session.Minutes.ToString("0.00", CultureInfo.InvariantCulture),
            session.Theme,
            session.Completed ? "yes" : "no"
        });

        try
        {
            DataFolder.EnsureExists();
            var file = DataFolder.SessionsFile;
            if (!File.Exists(file)) File.WriteAllText(file, Header + "\n");
            File.AppendAllText(file, row + "\n");

            Sessions.Add(session);
            Raise(nameof(Sessions));
            LastError = null;
        }
        catch (Exception error)
        {
            // Losing a row must never take the timer down with it.
            LastError = $"Could not write to sessions.csv: {error.Message}";
        }
    }
}
