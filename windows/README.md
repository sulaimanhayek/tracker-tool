# Focus for Windows

A native Windows app — Avalonia on .NET 8, compiled, no browser engine — that keeps
its data as plain files in a folder you choose.

It is the same app as the Mac one, down to the file format: point both at the same
folder (OneDrive, Dropbox, a network share) and each reads what the other wrote.
That is enforced by a check, not by intent — see [Checks](#checks).

## Installing

Grab the latest [release](https://github.com/sulaimanhayek/tracker-tool/releases):

| File | What it is |
| --- | --- |
| `Focus-Setup-<version>.exe` | Ordinary installer. Per-user, so no administrator needed. |
| `Focus.exe` | The whole app in one file. Put it anywhere and double-click it. |

Both are self-contained: the .NET runtime is inside them, so there is nothing to
install first. Windows 10 1809 or later, 64-bit.

The build is unsigned, so SmartScreen shows "Windows protected your PC" the first
time — **More info → Run anyway**.

## Building it yourself

Needs the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) and nothing
else. It builds and runs on macOS and Linux too, which is how it was developed.

| Command | What it does |
| --- | --- |
| `dotnet run --project Focus.App` | Build and run |
| `dotnet run --project Focus.Check` | Run the checks |
| `dotnet publish Focus.App -c Release -r win-x64 --self-contained -p:PublishSingleFile=true` | The portable `Focus.exe` |

`.github/workflows/windows.yml` does all of that on a Windows runner and attaches
the installer and the portable executable to each `v*` tag.

## What it does

- **Timer** — Focus (60 min), Short Break (5) and Long Break (15), each editable in
  Settings. A long break is suggested after every 4 focus rounds. Time left comes
  from a wall-clock deadline rather than a tick count, so a busy or sleeping PC
  cannot make it drift.
- **Themes** — what you are working on. The selected theme is what a session is
  recorded against.
- **Insights** — daily, weekly, monthly and yearly totals, a chart of recent
  periods, and a breakdown by theme, all computed from the log when the page is
  drawn.
- **Notes** — boards of draggable, resizable sticky notes. A board is one Word
  document, a section per note.
- **Settings** — durations (type the number or nudge it), the background, and the
  data folder, shown as the directory it is.

## The data

```
%USERPROFILE%\Documents\Focus\
  sessions.csv     append-only, one row per focus session
  themes.json      the list of theme names
  notes\
    Board.doc      one board: every note on it, a section each
    Board.json     where those notes sit on the board
```

The app asks where this folder should go the first time it runs, and writes nothing
until you answer. Change it later in **Settings → Storage**; you choose whether the
existing data comes along, and a file already at the destination is never
overwritten.

Settings themselves — the durations, the background, which folder — live in
`%APPDATA%\Focus\settings.json`, away from your data.

`sessions.csv` follows the same rules as the Mac app's: append only, focus time
only, interruptions banked honestly as `completed=no` rows, stretches under a minute
dropped, and nothing aggregated on disk.

Removing a note rewrites the board's document without it. A board you remove goes to
the **Recycle Bin** rather than being deleted, because it is a document; where there
is no Recycle Bin to use, it is moved aside rather than lost.

## Layout

```
Focus.Core/            No UI — the whole app apart from what you look at
  Models/              TimerMode, Session, Grain, Note, Background
  Services/            Prefs, DataFolder, Csv, SessionLog, ThemeStore,
                       TimerModel, Statistics, Sounds, NoteDocument, NotesStore
Focus.App/             The Avalonia app
  Shell.cs             The stores, the clock, and changing folder
  MainWindow           Header, pages, palette
  TimerView, NotesView, StatsView, SettingsWindow, WelcomeWindow
Focus.Check/           The checks
Installer/Focus.iss    Inno Setup script
```

## Checks

`dotnet run --project Focus.Check` runs 97 checks against a temporary folder,
covering CSV escaping, the session log's write-and-reload cycle, the bucketing
arithmetic behind every figure Insights shows, the timer including past-midnight
sessions, the notes board, and moving the data folder.

One section matters more than the rest. **Compatibility with the Mac app** holds a
board document produced by the actual Swift code and requires the C# output to match
it byte for byte. If either app's format drifts, that check fails rather than the
two apps quietly disagreeing about a folder they share.

There is no test framework here, matching the Mac app: the checks are a plain
console program, so they run anywhere the app does.
