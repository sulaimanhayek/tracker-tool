using System.Collections.ObjectModel;
using System.Globalization;
using System.Text.Json;

namespace Focus.Core;

/// The sticky-notes board, backed by one Word document per board.
///
/// `notes\Board.doc` holds every note on that board, oldest first, one section
/// each. Where a note sits on the board is furniture rather than content, so it
/// lives separately in `notes\Board.json`: delete that and you lose an
/// arrangement, never a word.
public sealed class NotesStore : Observable
{
    private string _selectedFolder = "Board";
    private bool _isStacked;
    private string? _lastError;
    private int _topZ = 1;

    private CancellationTokenSource? _pendingWrite;
    private CancellationTokenSource? _pendingLayout;
    private bool _writeQueued;
    private bool _layoutQueued;

    public ObservableCollection<string> Folders { get; } = new();
    public ObservableCollection<Note> Notes { get; } = new();

    public string SelectedFolder
    {
        get => _selectedFolder;
        set
        {
            if (value == _selectedFolder) return;
            Flush();
            Set(ref _selectedFolder, value);
            Prefs.Set("selectedNotesFolder", value);
            LoadNotes();
        }
    }

    public bool IsStacked { get => _isStacked; set => Set(ref _isStacked, value); }
    public string? LastError { get => _lastError; private set => Set(ref _lastError, value); }

    public NotesStore()
    {
        _selectedFolder = Prefs.GetString("selectedNotesFolder") ?? "Board";
        Reload();
    }

    public void Reload()
    {
        // Until the user has said where their data goes, nothing is read and
        // nothing is created.
        if (!DataFolder.IsChosen)
        {
            Folders.Clear();
            Folders.Add(_selectedFolder);
            Notes.Clear();
            return;
        }

        MigrateFolders();
        LoadFolders();
        if (!Folders.Contains(_selectedFolder))
        {
            Set(ref _selectedFolder, Folders.FirstOrDefault() ?? "Board", nameof(SelectedFolder));
        }
        LoadNotes();
    }

    private void LoadFolders()
    {
        Directory.CreateDirectory(DataFolder.NotesFolder);
        var found = Directory.EnumerateFiles(DataFolder.NotesFolder, $"*.{NoteDocument.FileExtension}")
            .Select(Path.GetFileNameWithoutExtension)
            .Where(name => !string.IsNullOrEmpty(name) && !name!.StartsWith("."))
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        // A board is only ever created on disk once there is something in it.
        if (found.Count == 0) found.Add(_selectedFolder!);

        Folders.Clear();
        foreach (var name in found) Folders.Add(name!);
        Raise(nameof(Folders));
    }

    /// Earlier versions kept a folder per board and a document per note. Those
    /// are folded into a single document the first time they are seen; the old
    /// folder is left exactly where it is rather than deleted, so nothing is
    /// taken away on the strength of a format change.
    private void MigrateFolders()
    {
        if (!Directory.Exists(DataFolder.NotesFolder)) return;

        foreach (var folder in Directory.EnumerateDirectories(DataFolder.NotesFolder))
        {
            var name = Path.GetFileName(folder);
            if (name.StartsWith(".")) continue;
            var destination = DocumentPath(name);
            if (File.Exists(destination)) continue;

            var files = Directory.EnumerateFiles(folder, $"*.{NoteDocument.FileExtension}")
                .OrderBy(f => f, StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (files.Count == 0) continue;

            var oldLayouts = ReadLayouts(Path.Combine(folder, "board.json"));
            var carried = new List<Note>();
            var moved = new Dictionary<string, NoteLayout>();

            foreach (var file in files)
            {
                var html = SafeRead(file);
                var created = LegacyDate(Path.GetFileName(file)) ?? DateTime.Now;
                var text = NoteDocument.NotesFromHtml(html, created, "h1").FirstOrDefault()?.Text ?? "";
                var id = NoteDocument.Stamp(created);
                carried.Add(new Note(id, created) { Text = text });
                if (oldLayouts.TryGetValue(Path.GetFileName(file), out var layout)) moved[id] = layout;
            }

            try { File.WriteAllText(destination, NoteDocument.Board(carried, name)); } catch { }
            WriteLayouts(moved, LayoutPath(name));
        }
    }

    /// The old per-note filename, `2026-09-19_21-25-54.doc`.
    private static DateTime? LegacyDate(string filename)
    {
        var stem = Path.GetFileNameWithoutExtension(filename);
        var head = stem.Length >= 19 ? stem[..19] : stem;
        return DateTime.TryParseExact(head, "yyyy-MM-dd_HH-mm-ss", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out var value) ? value : null;
    }

    public void AddFolder(string name)
    {
        var trimmed = Sanitise(name);
        if (trimmed.Length == 0) return;
        SelectedFolder = trimmed;
        WriteDocument(true);
        LoadFolders();
    }

    public void RenameFolder(string name)
    {
        var trimmed = Sanitise(name);
        if (trimmed.Length == 0 || trimmed == _selectedFolder) return;
        Flush();

        Move(DocumentPath(_selectedFolder), DocumentPath(trimmed));
        Move(LayoutPath(_selectedFolder), LayoutPath(trimmed));

        Set(ref _selectedFolder, trimmed, nameof(SelectedFolder));
        Prefs.Set("selectedNotesFolder", trimmed);
        // The board's own name is printed inside the document, so it is rewritten.
        WriteDocument(true);
        LoadFolders();
    }

    private static void Move(string from, string to)
    {
        try { if (File.Exists(from) && !File.Exists(to)) File.Move(from, to); } catch { }
    }

    /// Sends the board to the Recycle Bin rather than deleting it, because the
    /// document in it is the user's.
    public void TrashFolder()
    {
        if (Folders.Count < 2) return;
        _pendingWrite?.Cancel();
        _pendingLayout?.Cancel();
        _writeQueued = _layoutQueued = false;

        DataFolder.Recycle(DocumentPath(_selectedFolder));
        DataFolder.Recycle(LayoutPath(_selectedFolder));

        var remaining = Folders.Where(f => f != _selectedFolder).ToList();
        LoadFolders();
        Set(ref _selectedFolder, remaining.FirstOrDefault() ?? Folders.FirstOrDefault() ?? "Board",
            nameof(SelectedFolder));
        LoadNotes();
    }

    /// Strips anything that cannot be a filename, since the board's name is one.
    private static string Sanitise(string name)
    {
        var cleaned = name;
        foreach (var bad in Path.GetInvalidFileNameChars().Concat(new[] { '/', '\\', ':' }).Distinct())
            cleaned = cleaned.Replace(bad, '-');
        return cleaned.Trim();
    }

    /// The Word document for a board — the file to open, reveal or back up.
    public string DocumentPath(string folder) =>
        Path.Combine(DataFolder.NotesFolder, $"{folder}.{NoteDocument.FileExtension}");

    public string LayoutPath(string folder) =>
        Path.Combine(DataFolder.NotesFolder, $"{folder}.json");

    private void LoadNotes()
    {
        var parsed = NoteDocument.NotesFromHtml(SafeRead(DocumentPath(_selectedFolder)));
        var saved = ReadLayouts(LayoutPath(_selectedFolder));

        Notes.Clear();
        for (var index = 0; index < parsed.Count; index++)
        {
            var item = parsed[index];
            saved.TryGetValue(item.Id, out var layout);
            Notes.Add(new Note(item.Id, item.CreatedAt)
            {
                Text = item.Text,
                // A note whose layout is missing — typed into the document by
                // hand, say — still has to land somewhere sensible.
                X = layout?.X ?? 24 + index % 4 * 264,
                Y = layout?.Y ?? 24 + index / 4 * 264,
                Width = layout?.Width ?? Note.DefaultWidth,
                Height = layout?.Height ?? Note.DefaultHeight,
                Color = layout?.Color ?? NoteColor.All[index % NoteColor.All.Length].Key,
                Z = layout?.Z ?? index + 1
            });
        }

        _topZ = Math.Max(1, Notes.Count == 0 ? 1 : Notes.Max(n => n.Z));
        IsStacked = false;
        Raise(nameof(Notes));
    }

    public Note Add()
    {
        var now = DateTime.Now;
        var id = NoteDocument.Stamp(now);
        var attempt = 2;
        // Two notes made inside the same second must not share an identity.
        while (Notes.Any(n => n.Id == id)) id = $"{NoteDocument.Stamp(now)} ({attempt++})";

        var index = Notes.Count;
        _topZ++;
        var note = new Note(id, now)
        {
            X = 24 + index % 4 * 264,
            Y = 24 + index / 4 * 264,
            Color = NoteColor.All[index % NoteColor.All.Length].Key,
            Z = _topZ
        };

        Notes.Add(note);
        Raise(nameof(Notes));
        WriteDocument(true);
        SaveLayouts();
        return note;
    }

    /// Typing changes the text many times a second, so the document is written
    /// once things settle rather than once per keystroke.
    public void NoteTextChanged() => WriteDocument(false);

    public void NoteMoved() => ScheduleLayoutSave();

    public void Lift(Note note)
    {
        if (note.Z == _topZ) return;
        _topZ++;
        note.Z = _topZ;
        ScheduleLayoutSave();
    }

    /// Removing a note rewrites the board's document without it. The document
    /// itself only ever goes to the Recycle Bin, never a single note.
    public void Trash(Note note)
    {
        Notes.Remove(note);
        Raise(nameof(Notes));
        WriteDocument(true);
        SaveLayouts();
    }

    /// Lays the board out in columns, each note collapsed to its first line.
    public void Organise(double boardHeight)
    {
        const double step = 72, gap = 24;
        var perColumn = Math.Max(1, (int)((boardHeight - gap) / step));
        var columnWidth = (Notes.Count == 0 ? Note.DefaultWidth : Notes.Max(n => n.Width)) + gap;

        for (var index = 0; index < Notes.Count; index++)
        {
            Notes[index].X = gap + index / perColumn * columnWidth;
            Notes[index].Y = gap + index % perColumn * step;
            Notes[index].Z = index + 1;
        }

        _topZ = Math.Max(1, Notes.Count);
        IsStacked = true;
        SaveLayouts();
    }

    private void WriteDocument(bool immediately)
    {
        _pendingWrite?.Cancel();

        if (immediately) { WriteDocumentNow(); return; }

        _writeQueued = true;
        var source = new CancellationTokenSource();
        _pendingWrite = source;
        Task.Delay(800, source.Token).ContinueWith(task =>
        {
            if (task.IsCanceled) return;
            WriteDocumentNow();
        }, Scheduler);
    }

    /// Back on the UI thread where there is one; the checks have none.
    private static TaskScheduler Scheduler =>
        SynchronizationContext.Current is null
            ? TaskScheduler.Default
            : TaskScheduler.FromCurrentSynchronizationContext();

    private void WriteDocumentNow()
    {
        _writeQueued = false;
        var file = DocumentPath(_selectedFolder);
        try
        {
            Directory.CreateDirectory(DataFolder.NotesFolder);
            File.WriteAllText(file, NoteDocument.Board(Notes, _selectedFolder));
            LastError = null;
        }
        catch (Exception error)
        {
            LastError = $"Could not write {Path.GetFileName(file)}: {error.Message}";
        }
    }

    private void ScheduleLayoutSave()
    {
        _pendingLayout?.Cancel();
        _layoutQueued = true;
        var source = new CancellationTokenSource();
        _pendingLayout = source;
        Task.Delay(400, source.Token).ContinueWith(task =>
        {
            if (task.IsCanceled) return;
            SaveLayouts();
        }, Scheduler);
    }

    /// Forces pending writes out: for quitting, for switching boards, and before
    /// anything that reads the files back.
    public void Flush()
    {
        if (_layoutQueued)
        {
            _pendingLayout?.Cancel();
            SaveLayouts();
        }
        if (_writeQueued)
        {
            _pendingWrite?.Cancel();
            WriteDocumentNow();
        }
    }

    private static string SafeRead(string path)
    {
        try { return File.ReadAllText(path); } catch { return ""; }
    }

    private static Dictionary<string, NoteLayout> ReadLayouts(string path)
    {
        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, NoteLayout>>(File.ReadAllText(path),
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
        }
        catch { return new(); }
    }

    private void SaveLayouts()
    {
        _layoutQueued = false;
        var current = Notes.ToDictionary(note => note.Id, note => new NoteLayout
        {
            X = note.X, Y = note.Y, Width = note.Width, Height = note.Height,
            Color = note.Color, Z = note.Z
        });
        WriteLayouts(current, LayoutPath(_selectedFolder));
    }

    /// Keys are lower-cased to match what the Mac app writes, so a board carried
    /// between the two keeps its arrangement rather than starting again.
    private static void WriteLayouts(Dictionary<string, NoteLayout> layouts, string path)
    {
        try
        {
            Directory.CreateDirectory(DataFolder.NotesFolder);
            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            File.WriteAllText(path, JsonSerializer.Serialize(
                layouts.OrderBy(pair => pair.Key, StringComparer.Ordinal)
                       .ToDictionary(pair => pair.Key, pair => pair.Value),
                options));
        }
        catch { }
    }

    /// Writes everything out and returns the board's document, for opening it.
    public string? CompileFolder()
    {
        Flush();
        var file = DocumentPath(_selectedFolder);
        return File.Exists(file) ? file : null;
    }
}
