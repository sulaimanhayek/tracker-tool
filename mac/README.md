# Focus for macOS

A native SwiftUI Pomodoro timer that keeps its data as plain files you own.

> Early days, but the timer, themes, insights and the sticky-notes board all work.

## Building

Xcode is **not** required — the app builds with the Swift toolchain in the Command
Line Tools:

```bash
cd mac && ./Scripts/build-app.sh
```

That produces `build/Focus.app`. Open it with `open build/Focus.app`, or drag it to
`/Applications`.

| Command | What it does |
| --- | --- |
| `./Scripts/build-app.sh` | Release build, bundled as `Focus.app` |
| `./Scripts/build-app.sh debug` | Same, unoptimised |
| `swift build` | Compile without bundling |
| `swift run focus-check` | Run the checks |

The app is signed ad-hoc, so the first launch may need right-click → Open to get past
Gatekeeper. macOS will also ask once for access to your Documents folder.

If you install Xcode later, `open Package.swift` works — there is no `.xcodeproj` to
keep in step.

## What it does

- **Timer** — Focus (60 min), Short Break (5) and Long Break (15), each editable. A
  long break is suggested after every 4 focus rounds. Time left is derived from a
  wall-clock deadline rather than counted down tick by tick, so a busy or sleeping
  Mac cannot make it drift.
- **Themes** — "What are you working on today?". The selected theme is what a
  session is recorded against.
- **Insights** — daily, weekly, monthly and yearly totals, a chart of recent
  periods, and a breakdown by theme. All of it is computed from the log on the fly.
- **Notes** — a board of draggable, resizable coloured sticky notes in folders.
  Every note is its own Word document on disk, and a folder can be compiled into a
  single document.

## The data

```
~/Documents/Focus/
  sessions.csv     append-only, one row per focus session
  themes.json      the list of theme names
  notes/
    Board/
      2026-09-19_15-50-44.doc    one note
      board.json                 where the notes sit
    Board 2026-09-19_16-02-10.doc   a compiled folder
```

`sessions.csv` looks like this:

```csv
date,start,end,minutes,theme,completed
2026-09-19,09:00:00,10:00:00,60.00,Deep work,yes
2026-09-19,11:00:00,11:30:00,30.00,Reading,no
```

Rules it follows, so the file stays trustworthy:

- **Append only.** Rows are never rewritten, so a crash can cost at most the row
  being written, and an edit you make between sessions is not clobbered.
- **Focus time only.** Breaks are not work and are not logged.
- **Interruptions are recorded honestly.** Pausing or switching mode banks the time
  earned so far as a row with `completed=no`, so a session you abandoned halfway
  counts as half, not as nothing and not as a full hour. One focus hour with two
  pauses is three rows.
- **Stretches under a minute are dropped**, to keep the file free of noise from a
  mis-click.
- **Nothing is aggregated on disk.** Every daily, weekly, monthly and yearly figure
  is derived from this file when the app draws it, so the reports can never
  disagree with the record.

### Notes

A note is a Word document named after the moment it was created, so the filename is
the record of when you wrote it — file dates move when a file is copied. Open one in
Word, Pages or TextEdit; the app reads its own format back exactly, and if Word
rewrites a file the text is still recovered, though its formatting is not.

Where a note sits, how big it is and what colour it is are furniture rather than
content, so they live apart in `board.json`. Delete that file and you lose an
arrangement, never a word. Drop a `.doc` into a folder by hand and it appears on the
board on the next reload.

Notes and folders you remove go to the Trash rather than being deleted, because they
are documents.

### Working with the folder

Use *Reveal data folder* to open it in Finder, and *Reload from disk* after editing
it by hand. To keep the files somewhere else, the path lives in the `dataFolderPath`
default.

## Layout

```
Sources/
  FocusKit/            No UI — safe to exercise on its own
    Models/            TimerMode, Session, Grain, Note
    Services/          DataFolder, CSV, SessionLog, ThemeStore, TimerModel,
                       Statistics, NoteDocument, NotesStore
  Focus/               The app
    FocusApp.swift     Entry point, wiring, menu commands
    Views/             ContentView, TimerView, RingView, StatsView,
                       NotesView, NoteCardView, FlowLayout
  FocusCheck/          The checks
Scripts/build-app.sh   Builds the .app bundle
Resources/Info.plist   Bundle metadata
```

## Checks

`swift run focus-check` runs 61 checks against a temporary data folder, covering CSV
escaping and round-tripping, the session log's write-and-reload cycle, the bucketing
arithmetic behind every figure the Insights page shows, and the notes board: a
document's text surviving the trip to disk and back, layout and colour persisting,
folders, compiling, and trashing.

XCTest ships with Xcode, which this project deliberately does not require, so the
checks are a plain executable rather than a test target. If you install Xcode, they
convert to XCTest with little more than a rename.
