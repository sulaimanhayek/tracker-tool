using System.Globalization;
using Focus.Core;

// Checks for the parts that must not be got wrong: the session log's round trip
// through CSV, the arithmetic behind every figure the app reports, and the board
// document — which the Mac app reads too, so its format is a contract.

var failures = 0;

void Check(string name, bool condition)
{
    Console.WriteLine(condition ? $"  ok   {name}" : $"  FAIL {name}");
    if (!condition) failures++;
}

DateTime At(string text) =>
    DateTime.ParseExact(text, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);

/// Where two documents first part company, so a failure says what changed
/// rather than only that something did.
string Difference(string actual, string expected)
{
    var at = 0;
    while (at < actual.Length && at < expected.Length && actual[at] == expected[at]) at++;
    string Around(string text) =>
        text.Substring(Math.Max(0, at - 30), Math.Min(text.Length, at + 30) - Math.Max(0, at - 30))
            .Replace("\r", "\\r").Replace("\n", "\\n");
    return $"       at character {at}\n       got      {Around(actual)}\n       expected {Around(expected)}";
}

Console.WriteLine("CSV");
Check("plain field is left alone", Csv.Escape("Deep work") == "Deep work");
Check("comma forces quoting", Csv.Escape("Reading, writing") == "\"Reading, writing\"");
Check("quote is doubled", Csv.Escape("He said \"go\"") == "\"He said \"\"go\"\"\"");
Check("round trip keeps a comma", Csv.Parse(Csv.Row(new[] { "a,b", "c" })).SequenceEqual(new[] { "a,b", "c" }));
Check("round trip keeps a quote", Csv.Parse(Csv.Row(new[] { "say \"hi\"", "x" })).SequenceEqual(new[] { "say \"hi\"", "x" }));
Check("empty fields survive", Csv.Parse("a,,c").SequenceEqual(new[] { "a", "", "c" }));

// A run must not inherit the last one's state, or these stop being deterministic.
Prefs.Reset();
var folder = Path.Combine(Path.GetTempPath(), $"focus-check-{Guid.NewGuid()}");
DataFolder.SetPath(folder);
DataFolder.MarkChosen();

Console.WriteLine("\nSession log");
var log = new SessionLog();
Check("starts empty", log.Sessions.Count == 0);

var written = new[]
{
    new Session(At("2026-09-19 09:00:00"), At("2026-09-19 10:00:00"), "Deep work", true),
    new Session(At("2026-09-19 11:00:00"), At("2026-09-19 11:30:00"), "Reading, notes", false),
    new Session(At("2026-09-18 14:00:00"), At("2026-09-18 15:00:00"), "Deep work", true)
};
foreach (var session in written) log.Append(session);

Check("three rows were written", log.Sessions.Count == 3);
Check("the header is written once",
    File.ReadAllLines(DataFolder.SessionsFile).Count(line => line == SessionLog.Header) == 1);
Check("nothing is rewritten", File.ReadAllLines(DataFolder.SessionsFile).Length == 4);

var reloaded = new SessionLog();
Check("every row comes back", reloaded.Sessions.Count == 3);
Check("a theme with a comma survives", reloaded.Sessions[1].Theme == "Reading, notes");
Check("minutes come back", Math.Abs(reloaded.Sessions[0].Minutes - 60) < 0.001);
Check("completion comes back", reloaded.Sessions[0].Completed && !reloaded.Sessions[1].Completed);
Check("a session under a second is not written",
    WroteNothing(() => reloaded.Append(new Session(At("2026-09-19 12:00:00"), At("2026-09-19 12:00:00"), "x", true))));

bool WroteNothing(Action action)
{
    var before = File.ReadAllLines(DataFolder.SessionsFile).Length;
    action();
    return File.ReadAllLines(DataFolder.SessionsFile).Length == before;
}

Console.WriteLine("\nA session that runs past midnight");
File.AppendAllText(DataFolder.SessionsFile, "2026-09-17,23:30:00,00:30:00,60.00,Night,yes\n");
var overnight = new SessionLog().Sessions.First(s => s.Theme == "Night");
Check("it is dated by when it began", overnight.Start.Day == 17);
Check("and it lasts an hour, not minus twenty-three", overnight.Seconds == 3600);

Console.WriteLine("\nStatistics");
var now = At("2026-09-19 18:00:00");
Check("today's total is today's only", Statistics.Total(written, Grain.Day, now) == 5400);
Check("the week gathers both days", Statistics.Total(written, Grain.Week, now) == 9000);
Check("a day bucket exists for every day in the span",
    Statistics.Buckets(written, Grain.Day, now).Count == Grain.Day.Span());
Check("buckets run oldest first",
    Statistics.Buckets(written, Grain.Day, now).Zip(Statistics.Buckets(written, Grain.Day, now).Skip(1))
        .All(pair => pair.First.Start < pair.Second.Start));
Check("the last bucket is today",
    Statistics.Buckets(written, Grain.Day, now).Last().Start == now.Date);
Check("an empty period is kept rather than closed up",
    Statistics.Buckets(written, Grain.Day, now).Any(b => b.Seconds == 0));
Check("themes are totalled",
    Statistics.ByTheme(written, Grain.Day, now).First().Theme == "Deep work");
Check("and sorted by time",
    Statistics.ByTheme(written, Grain.Week, now).Select(t => t.Seconds).SequenceEqual(new[] { 7200, 1800 }));
Check("a blank theme is named", Statistics.ByTheme(
    new[] { new Session(At("2026-09-19 08:00:00"), At("2026-09-19 08:30:00"), "", true) },
    Grain.Day, now).First().Theme == "No theme");

Console.WriteLine("\nColours and the chart in one pass");
{
    var monday = new Session(At("2026-09-21 09:00:00"), At("2026-09-21 10:00:00"), "Writing", true);
    var mondayAdmin = new Session(At("2026-09-21 11:00:00"), At("2026-09-21 11:30:00"), "Admin", true);
    var tuesday = new Session(At("2026-09-22 09:00:00"), At("2026-09-22 09:30:00"), "Admin", true);
    var log2 = new[] { monday, mondayAdmin, tuesday };
    var then = At("2026-09-22 20:00:00");

    var order = ChartPalette.Order(log2);
    Check("themes are coloured in the order they first appear",
        string.Join(",", order) == "Writing,Admin");
    Check("a theme named twice is only counted once",
        ChartPalette.Order(log2.Concat(log2)).Count == order.Count);
    Check("an unnamed theme is still shown",
        ChartPalette.Order(new[] { new Session(At("2026-09-21 09:00:00"), At("2026-09-21 09:10:00"), "", true) })[0] == "No theme");
    Check("the palette wraps rather than running out",
        ChartPalette.Colour(ChartPalette.Colours.Length) == ChartPalette.Colours[0]);
    Check("a colour before the first is still a colour", ChartPalette.Colour(-1) == ChartPalette.Colours[^1]);

    var periods = Statistics.Breakdown(log2, Grain.Day, then);
    Check("a bar per period", periods.Count == Grain.Day.Span());
    Check("the last bar is today", periods[^1].Start == then.Date);
    Check("each bar totals its sessions", periods[^1].Seconds == 1800);
    Check("a bar is split by theme",
        string.Join(",", periods[^2].Slices.Select(s => s.Theme)) == "Writing,Admin");
    Check("a theme keeps its colour from bar to bar",
        periods[^1].Slices[0].Colour == periods[^2].Slices[1].Colour);
    Check("the slices add up to the bar",
        periods[^2].Slices.Sum(s => s.Seconds) == periods[^2].Seconds);
    Check("a period with nothing in it is still a bar",
        periods[0].Seconds == 0 && periods[0].Slices.Count == 0);
    Check("the bar carries its own labels", periods[^1].Title == Grain.Day.Title(then.Date));
    Check("the breakdown agrees with the totals it replaces",
        periods[^1].Seconds == Statistics.Total(log2, Grain.Day, then));
}

Console.WriteLine("\nHow wide a bar is");
{
    Check("a bar never grows past the widest",
        ChartLayout.BarWidth(5, 600) == ChartLayout.WidestBar);
    Check("a crowded chart makes them thinner",
        ChartLayout.BarWidth(60, 600) < ChartLayout.WidestBar);
    Check("a bar is always drawable", ChartLayout.BarWidth(400, 100) >= 2);
    Check("the same width whatever the period",
        ChartLayout.BarWidth(14, 600) == ChartLayout.BarWidth(5, 600));
    Check("the columns span the chart",
        Math.Abs((ChartLayout.BarWidth(14, 600) + ChartLayout.Gap(14, 600, ChartLayout.BarWidth(14, 600))) * 14 - 600) < 0.001);
    Check("bars never touch",
        ChartLayout.Gap(200, 600, ChartLayout.BarWidth(200, 600)) >= ChartLayout.TightestGap);
    Check("a cramped chart still fits its bars",
        (ChartLayout.BarWidth(14, 200) + ChartLayout.TightestGap) * 14 <= 200.001);
}

Console.WriteLine("\nWhere the hover label sits");
{
    Check("a short bar leaves the label above it",
        ChartLabel.Top(20, 180, ChartLabel.Height(2)) + ChartLabel.Height(2) + ChartLabel.Clearance <= 180 - 20 + 0.001);
    Check("a taller label is a taller label", ChartLabel.Height(4) > ChartLabel.Height(2));
    Check("an empty period still has a line to show", ChartLabel.Height(0) > 0);
    Check("a bar with no room above it keeps the label on the chart",
        ChartLabel.Top(180, 180, ChartLabel.Height(6)) == 0);
    Check("the label stays on the chart at the left edge",
        ChartLabel.Left(5, 600, 170) == 0);
    Check("and at the right edge", ChartLabel.Left(598, 600, 170) == 430);
    Check("otherwise it is centred on the bar", ChartLabel.Left(300, 600, 170) == 215);
}

Console.WriteLine("\nTime added by hand");
{
    var then = At("2026-09-20 18:00:00");
    var entry = ManualEntry.Build(At("2026-09-20 00:00:00"), new TimeSpan(9, 0, 0), new TimeSpan(10, 30, 0), "Reading");
    Check("a hand-typed stretch is an ordinary session", entry.Seconds == 90 * 60);
    Check("and it can be saved", ManualEntry.Problem(entry, then) is null);
    Check("a minute is the shortest worth recording",
        ManualEntry.Problem(ManualEntry.Build(then, new TimeSpan(9, 0, 0), new TimeSpan(9, 0, 0), ""), then) is not null);
    Check("half a day is the longest",
        ManualEntry.Problem(ManualEntry.Build(then, new TimeSpan(1, 0, 0), new TimeSpan(14, 0, 0), ""), then) is not null);
    Check("time yet to happen is refused",
        ManualEntry.Problem(ManualEntry.Build(then, new TimeSpan(19, 0, 0), new TimeSpan(20, 0, 0), ""), then) is not null);
    Check("a night shift rolls past midnight",
        ManualEntry.Build(then, new TimeSpan(23, 0, 0), new TimeSpan(1, 0, 0), "").Seconds == 2 * 3600);

    var already = new[] { new Session(At("2026-09-20 09:30:00"), At("2026-09-20 10:00:00"), "Writing", true) };
    Check("an entry over one already logged is spotted", ManualEntry.FirstOverlap(entry, already) is not null);
    Check("ending exactly when the next begins is not",
        !ManualEntry.Overlap(entry, new Session(At("2026-09-20 10:30:00"), At("2026-09-20 11:00:00"), "Writing", true)));
    Check("an entry the log knows nothing about is clear",
        ManualEntry.FirstOverlap(ManualEntry.Build(then, new TimeSpan(14, 0, 0), new TimeSpan(15, 0, 0), ""), already) is null);
}

Console.WriteLine("\nFormatting");
Check("minutes alone", Statistics.Format(1800) == "30m");
Check("whole hours", Statistics.Format(7200) == "2h");
Check("hours and minutes", Statistics.Format(5430) == "1h 30m");
Check("nothing is zero minutes", Statistics.Format(0) == "0m");
Check("the label's clock pads its minutes", Statistics.Clock(5430) == "1:30");
Check("and keeps a long day in hours", Statistics.Clock(36000) == "10:00");
Check("under an hour still reads as a clock", Statistics.Clock(300) == "0:05");

Console.WriteLine("\nThemes");
var themes = new ThemeStore();
themes.Add("Deep work");
themes.Add("Deep work");
themes.Add("  ");
Check("a theme is added once", themes.Themes.Count == 1);
Check("blank is refused", !themes.Themes.Contains("  "));
Check("the first added is selected", themes.Selected == "Deep work");
themes.Add("Reading");
Check("themes persist", new ThemeStore().Themes.Count == 2);
themes.Remove("Deep work");
Check("removing clears the selection", themes.Selected is null);
Check("and it is gone from disk", !new ThemeStore().Themes.Contains("Deep work"));

Console.WriteLine("\nThe timer");
// Its own folder: these count rows, and the log above already has some.
var timerFolder = Path.Combine(Path.GetTempPath(), $"focus-timer-{Guid.NewGuid()}");
DataFolder.SetPath(timerFolder);
var clock = At("2026-09-19 09:00:00");
var timerLog = new SessionLog();
var timerThemes = new ThemeStore();
timerThemes.Add("Deep work");
var timer = new TimerModel(timerLog, timerThemes, () => clock);
Check("it starts on focus", timer.Mode == TimerMode.Focus);
Check("with the focus duration", Math.Abs(timer.Total - timer.Durations[TimerMode.Focus] * 60) < 0.001);

timer.SetDuration(TimerMode.Focus, 2);
Check("a duration is remembered", Prefs.GetInt("duration.focus") == 2);
Check("and is clamped", ClampedTo480());
bool ClampedTo480()
{
    timer.SetDuration(TimerMode.LongBreak, 10_000);
    var held = timer.Durations[TimerMode.LongBreak] == 480;
    timer.SetDuration(TimerMode.LongBreak, TimerMode.LongBreak.DefaultMinutes());
    return held;
}

timer.Start();
clock = clock.AddSeconds(90);
timer.Tick();
Check("time left is read off the clock, not counted", Math.Abs(timer.Remaining - 30) < 0.001);
timer.Pause();
Check("pausing banks the time so far", timerLog.Sessions.Count == 1);
Check("as an unfinished session", !timerLog.Sessions[0].Completed);
Check("against the selected theme", timerLog.Sessions[0].Theme == "Deep work");

timer.Start();
clock = clock.AddSeconds(120);
timer.Tick();
Check("running out completes the session", timerLog.Sessions.Count == 2 && timerLog.Sessions[1].Completed);
Check("and moves on to a break", timer.Mode == TimerMode.ShortBreak);

clock = clock.AddSeconds(10);
timer.Start();
clock = clock.AddSeconds(5);
timer.Pause();
Check("break time is not logged", timerLog.Sessions.Count == 2);

var shortLog = new SessionLog();
var rowsBefore = shortLog.Sessions.Count;
var shortTimer = new TimerModel(shortLog, timerThemes, () => clock);
shortTimer.Start();
clock = clock.AddSeconds(30);
shortTimer.Pause();
Check("a stretch under a minute is dropped", shortLog.Sessions.Count == rowsBefore);

DataFolder.SetPath(folder);
try { Directory.Delete(timerFolder, true); } catch { }

Console.WriteLine("\nNotes: a document round trip");
var notes = new NotesStore();
var note = notes.Add();
note.Text = "Shopping\nMilk\n\nBread";
notes.NoteTextChanged();
notes.Flush();

var document = File.ReadAllText(notes.DocumentPath(notes.SelectedFolder));
Check("the board's name heads the document", document.Contains("<h1>Board</h1>"));
Check("the note's first line is its heading", document.Contains("<h2>Shopping</h2>"));
Check("its stamp is printed, not hidden in a filename", document.Contains($"<p class=\"stamp\">{note.Id}</p>"));
Check("a blank line is kept", document.Contains("<p>&nbsp;</p>"));

var reread = new NotesStore();
Check("the note comes back", reread.Notes.Count == 1);
Check("with its text", reread.Notes[0].Text == "Shopping\nMilk\n\nBread");
Check("and its identity", reread.Notes[0].Id == note.Id);

Console.WriteLine("\nNotes: the board");
var second = notes.Add();
second.Text = "Second";
notes.NoteTextChanged();
notes.Flush();
Check("both notes are in one document",
    File.ReadAllText(notes.DocumentPath("Board")).Split("<hr>").Length == 2);
Check("the board file is one document, not a folder",
    File.Exists(notes.DocumentPath("Board")) && !Directory.Exists(Path.Combine(DataFolder.NotesFolder, "Board")));

second.X = 500;
second.Color = "mint";
notes.NoteMoved();
notes.Flush();
var afterMove = new NotesStore();
Check("where a note sits is remembered", afterMove.Notes.First(n => n.Id == second.Id).X == 500);
Check("as is its colour", afterMove.Notes.First(n => n.Id == second.Id).Color == "mint");
Check("layout lives apart from the words",
    File.Exists(notes.LayoutPath("Board")) &&
    !File.ReadAllText(notes.LayoutPath("Board")).Contains("Second"));

notes.Trash(second);
notes.Flush();
Check("a trashed note leaves the document", !File.ReadAllText(notes.DocumentPath("Board")).Contains("<h2>Second</h2>"));
Check("and the other one stays", File.ReadAllText(notes.DocumentPath("Board")).Contains("<h2>Shopping</h2>"));

Console.WriteLine("\nNotes: a section typed into Word by hand");
var handEdited = NoteDocument.NotesFromHtml(
    "<html><body><h1>Board</h1><h2>Typed</h2><p>By hand</p></body></html>", At("2026-09-19 12:00:00"));
Check("it is kept rather than dropped", handEdited.Count == 1);
Check("with its text", handEdited[0].Text == "Typed\nBy hand");
Check("and is given a stamp", NoteDocument.DateFromStamp(handEdited[0].Id) is not null);

var duplicated = NoteDocument.NotesFromHtml(
    "<h2>A</h2><p class=\"stamp\">2026-09-19 12:00:00</p>\n<hr>\n<h2>B</h2><p class=\"stamp\">2026-09-19 12:00:00</p>");
Check("two sections cannot share an identity", duplicated[0].Id != duplicated[1].Id);

Console.WriteLine("\nNotes: folders from the old layout");
var oldBoard = Path.Combine(DataFolder.NotesFolder, "Archive");
Directory.CreateDirectory(oldBoard);
File.WriteAllText(Path.Combine(oldBoard, "2026-09-01_10-00-00.doc"),
    "<html><body><h1>Older note</h1><p>Still here</p></body></html>");
var migrated = new NotesStore();
Check("the old folder becomes a document", File.Exists(migrated.DocumentPath("Archive")));
Check("the old folder is left alone", Directory.Exists(oldBoard));
migrated.SelectedFolder = "Archive";
Check("with its text", migrated.Notes.Count == 1 && migrated.Notes[0].Text == "Older note\nStill here");
Check("dated from its old filename", migrated.Notes[0].CreatedAt == At("2026-09-01 10:00:00"));

Console.WriteLine("\nCompatibility with the Mac app");
// Pinned against the Swift implementation's own output, byte for byte. One
// folder has to serve both apps, so this format is a contract, not a detail.
var macNote = new Note("2026-09-19 12:00:00", At("2026-09-19 12:00:00"))
{
    Text = "Shopping & <plans>\nMilk\n\nBread"
};
var expected = """
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Board &amp; co</title>
<style>
body { font-family: Calibri, sans-serif; font-size: 11pt; }
h1 { font-size: 20pt; margin: 0 0 16pt; }
h2 { font-size: 14pt; margin: 0 0 4pt; }
.stamp { color: #666666; font-size: 9pt; margin: 0 0 12pt; }
hr { border: 0; border-top: 1px solid #cccccc; margin: 24pt 0; }
</style></head>
<body>
<h1>Board &amp; co</h1>
<h2>Shopping &amp; &lt;plans&gt;</h2>
<p class="stamp">2026-09-19 12:00:00</p>
<p>Milk</p>
<p>&nbsp;</p>
<p>Bread</p>
</body></html>
""";
// This file may be checked out with CRLF on Windows; the contract is LF, and
// the document the app writes is LF, so the fixture is read as LF too.
expected = expected.Replace("\r\n", "\n");
var rendered = NoteDocument.Board(new[] { macNote }, "Board & co");
Check("a board renders exactly as the Mac app writes it", rendered == expected);
if (rendered != expected) Console.WriteLine(Difference(rendered, expected));

var backFromMac = NoteDocument.NotesFromHtml(expected);
Check("and reads back from that document", backFromMac.Count == 1);
Check("with the same identity", backFromMac[0].Id == "2026-09-19 12:00:00");
Check("and the same words, ampersands and angle brackets intact",
    backFromMac[0].Text == "Shopping & <plans>\nMilk\n\nBread");

Console.WriteLine("\nBackgrounds");
Check("all six palettes are offered", Background.All.Length == 6);
Check("every key is distinct", Background.All.Select(b => b.Key).Distinct().Count() == 6);
Check("a hex channel reads back", Background.Rgb("#12141a") == ((byte)0x12, (byte)0x14, (byte)0x1a));
Check("white is white", Background.Rgb("#ffffff") == ((byte)255, (byte)255, (byte)255));
Check("a malformed value is black rather than a crash", Background.Rgb("nonsense") == ((byte)0, (byte)0, (byte)0));
Check("paper is a light palette", !Background.Named("paper").IsDark);
Check("an unknown key falls back to the first", Background.Named("zzz").Key == "midnight");
var palette = new BackgroundStore();
Check("a new install starts on midnight", palette.Selected == "midnight");
palette.Selected = "forest";
Check("the choice is remembered", new BackgroundStore().Current.Label == "Forest");
Prefs.Remove("background");

Console.WriteLine("\nThe data folder as a directory");
var shown = Path.Combine(Path.GetTempPath(), $"focus-listing-{Guid.NewGuid()}");
Directory.CreateDirectory(Path.Combine(shown, "notes"));
File.WriteAllText(Path.Combine(shown, "sessions.csv"), "x");
File.WriteAllText(Path.Combine(shown, ".hidden"), "x");
File.WriteAllText(Path.Combine(shown, "notes", "Board.doc"), "x");
var listing = DataFolder.Listing(shown);
Check("the folder's own files are listed", listing.Select(e => e.Name).SequenceEqual(new[] { "notes", "sessions.csv" }));
Check("folders come first", listing[0].IsDirectory);
Check("dot files are left out", listing.All(e => !e.Name.StartsWith(".")));
Check("a folder shows what is in it", listing[0].Children.Single().Name == "Board.doc");
Check("but only a level deep", DataFolder.Listing(shown, 0)[0].Children.Count == 0);
Directory.Delete(shown, true);

Console.WriteLine("\nMoving the data folder");
var moved = Path.Combine(Path.GetTempPath(), $"focus-move-{Guid.NewGuid()}");
var before = DataFolder.Path;
var relocation = DataFolder.Relocate(moved, true);
Check("the app now points at the new folder", DataFolder.Path == moved);
Check("the data came with it", File.Exists(Path.Combine(moved, "sessions.csv")));
Check("nothing is left behind", !File.Exists(Path.Combine(before, "sessions.csv")));
Check("it reports what it moved", relocation.Moved.Contains("sessions.csv"));

var occupied = Path.Combine(Path.GetTempPath(), $"focus-move-taken-{Guid.NewGuid()}");
Directory.CreateDirectory(occupied);
File.WriteAllText(Path.Combine(occupied, "sessions.csv"), "mine");
var second2 = DataFolder.Relocate(occupied, true);
Check("an existing file at the destination is kept", second2.Kept.Contains("sessions.csv"));
Check("and it keeps its own contents", File.ReadAllText(Path.Combine(occupied, "sessions.csv")) == "mine");
Check("the one it could not move stays where it was", File.Exists(Path.Combine(moved, "sessions.csv")));

var fresh = Path.Combine(Path.GetTempPath(), $"focus-move-fresh-{Guid.NewGuid()}");
DataFolder.Relocate(fresh, false);
Check("starting fresh creates the folder", Directory.Exists(fresh));
Check("starting fresh brings nothing", !Directory.EnumerateFileSystemEntries(fresh).Any());

foreach (var path in new[] { folder, moved, occupied, fresh })
    try { Directory.Delete(path, true); } catch { }
Prefs.Reset();

Console.WriteLine();
if (failures == 0)
{
    Console.WriteLine("All checks passed.");
    return 0;
}
Console.WriteLine($"{failures} check(s) failed.");
return 1;
