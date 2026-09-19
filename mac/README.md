# Focus for macOS

A native SwiftUI Pomodoro timer that keeps its data as plain files you own.

> Early days. The timer, theme tracking and insights are working; the sticky-notes
> board is not built yet. The [web app](../web) has it in the meantime.

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

## The data

```
~/Documents/Focus/
  sessions.csv     append-only, one row per focus session
  themes.json      the list of theme names
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

Use *Reveal data folder* to open it in Finder, and *Reload from disk* after editing
it by hand. To keep the files somewhere else, the path lives in the `dataFolderPath`
default.

## Layout

```
Sources/
  FocusKit/            No UI — safe to exercise on its own
    Models/            TimerMode, Session, Grain
    Services/          DataFolder, CSV, SessionLog, ThemeStore, TimerModel, Statistics
  Focus/               The app
    FocusApp.swift     Entry point, wiring, menu commands
    Views/             ContentView, TimerView, RingView, StatsView, FlowLayout
  FocusCheck/          The checks
Scripts/build-app.sh   Builds the .app bundle
Resources/Info.plist   Bundle metadata
```

## Checks

`swift run focus-check` covers CSV escaping and round-tripping, the session log's
write-and-reload cycle against a temporary folder, and the bucketing arithmetic
behind every figure the Insights page shows.

XCTest ships with Xcode, which this project deliberately does not require, so the
checks are a plain executable rather than a test target. If you install Xcode, they
convert to XCTest with little more than a rename.
