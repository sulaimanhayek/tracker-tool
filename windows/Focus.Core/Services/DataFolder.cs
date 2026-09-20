namespace Focus.Core;

/// Where the app keeps its files. One folder, plain formats, no database — the
/// point is that everything stays readable without this app, and that the same
/// folder opens identically on a Mac.
public static class DataFolder
{
    public const string OverrideKey = "dataFolderPath";
    private const string ChosenKey = "hasChosenDataFolder";

    /// Whether the user has been asked where their data should live. Until they
    /// have, the app has written nothing anywhere.
    public static bool IsChosen => Prefs.GetBool(ChosenKey);

    public static void MarkChosen() => Prefs.Set(ChosenKey, true);

    public static string Path
    {
        get
        {
            var stored = Prefs.GetString(OverrideKey);
            return string.IsNullOrEmpty(stored) ? DefaultPath : stored;
        }
    }

    public static string DefaultPath => System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Focus");

    public static void SetPath(string? path)
    {
        if (path is null) Prefs.Remove(OverrideKey);
        else Prefs.Set(OverrideKey, path);
    }

    public static string SessionsFile => System.IO.Path.Combine(Path, "sessions.csv");
    public static string ThemesFile => System.IO.Path.Combine(Path, "themes.json");
    public static string NotesFolder => System.IO.Path.Combine(Path, "notes");

    public static bool EnsureExists()
    {
        try { Directory.CreateDirectory(Path); return true; }
        catch { return false; }
    }

    /// What moving the folder did, so the app can say so rather than guess.
    public sealed class Relocation
    {
        public List<string> Moved { get; } = new();
        public List<string> Kept { get; } = new();
    }

    /// Points the app at another folder, optionally bringing what is already
    /// there. Anything already present at the destination is left exactly as it
    /// is — a file is never overwritten here, so the worst case is two folders
    /// to tidy by hand rather than a note lost.
    public static Relocation Relocate(string destination, bool movingExisting)
    {
        var result = new Relocation();
        var source = Path;
        Directory.CreateDirectory(destination);

        if (movingExisting && !SamePath(source, destination) && Directory.Exists(source))
        {
            foreach (var item in Directory.EnumerateFileSystemEntries(source))
            {
                var name = System.IO.Path.GetFileName(item);
                if (name.StartsWith(".")) continue;
                var to = System.IO.Path.Combine(destination, name);

                if (File.Exists(to) || Directory.Exists(to)) { result.Kept.Add(name); continue; }

                try
                {
                    if (Directory.Exists(item)) Directory.Move(item, to);
                    else File.Move(item, to);
                    result.Moved.Add(name);
                }
                catch { result.Kept.Add(name); }
            }
        }

        SetPath(destination);
        MarkChosen();
        return result;
    }

    private static bool SamePath(string a, string b) =>
        string.Equals(
            System.IO.Path.GetFullPath(a).TrimEnd(System.IO.Path.DirectorySeparatorChar),
            System.IO.Path.GetFullPath(b).TrimEnd(System.IO.Path.DirectorySeparatorChar),
            StringComparison.OrdinalIgnoreCase);

    /// One entry in the data folder, for showing it as a directory.
    public sealed record Entry(string Name, bool IsDirectory, IReadOnlyList<Entry> Children);

    /// What is actually in the folder, a level deep, so the app can show the
    /// files rather than describe them. Directories come first.
    public static List<Entry> Listing(string? folder = null, int depth = 1)
    {
        var root = folder ?? Path;
        if (!Directory.Exists(root)) return new();

        return Directory.EnumerateFileSystemEntries(root)
            .Select(System.IO.Path.GetFileName)
            .Where(name => !string.IsNullOrEmpty(name) && !name!.StartsWith("."))
            .Select(name =>
            {
                var full = System.IO.Path.Combine(root, name!);
                var isDirectory = Directory.Exists(full);
                return new Entry(name!, isDirectory,
                    isDirectory && depth > 0 ? Listing(full, depth - 1) : new List<Entry>());
            })
            .OrderByDescending(e => e.IsDirectory)
            .ThenBy(e => e.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    /// Opens the folder in Explorer (or Finder, when these checks run on a Mac).
    public static void Reveal()
    {
        EnsureExists();
        try
        {
            if (OperatingSystem.IsWindows())
                System.Diagnostics.Process.Start("explorer.exe", $"\"{Path}\"");
            else
                System.Diagnostics.Process.Start("open", $"\"{Path}\"");
        }
        catch { }
    }

    /// Opens a file with whatever the machine uses for it — Word, for a board.
    public static void Open(string file)
    {
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(file)
            {
                UseShellExecute = true
            });
        }
        catch { }
    }

    /// Deletes to the Recycle Bin where there is one, because a board is the
    /// user's document and should be recoverable. Shell32 directly rather than
    /// a VB compatibility assembly, so this library still builds anywhere.
    public static void Recycle(string path)
    {
        if (!File.Exists(path) && !Directory.Exists(path)) return;

        if (OperatingSystem.IsWindows() && RecycleViaShell(path)) return;

        // No Recycle Bin here: keep the file, out of the way, rather than lose it.
        try
        {
            var aside = System.IO.Path.Combine(System.IO.Path.GetDirectoryName(path)!, ".trashed");
            Directory.CreateDirectory(aside);
            File.Move(path, System.IO.Path.Combine(aside,
                $"{DateTime.Now:yyyy-MM-dd_HH-mm-ss}-{System.IO.Path.GetFileName(path)}"), true);
        }
        catch { }
    }

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private struct ShFileOpStruct
    {
        public IntPtr Window;
        public uint Function;
        public string From;
        public string? To;
        public ushort Flags;
        public bool AnyOperationsAborted;
        public IntPtr NameMappings;
        public string? ProgressTitle;
    }

    [System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern int SHFileOperation(ref ShFileOpStruct operation);

    private static bool RecycleViaShell(string path)
    {
        try
        {
            var operation = new ShFileOpStruct
            {
                Function = 0x0003,            // FO_DELETE
                From = path + "\0\0",
                Flags = 0x0040 | 0x0010 | 0x0004 | 0x0400 // ALLOWUNDO | NOCONFIRMATION | SILENT | NOERRORUI
            };
            return SHFileOperation(ref operation) == 0;
        }
        catch { return false; }
    }
}
