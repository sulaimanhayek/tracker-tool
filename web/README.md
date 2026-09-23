# Focus

A Pomodoro timer and a sticky-notes board, in one small React app. No backend, no
accounts, no tracking — everything lives in the browser.

> This is the web app. The native versions, which keep their data as files on disk,
> live in [`../mac`](../mac) and [`../windows`](../windows). See the
> [repository README](../README.md).

## Features

### Timer

- A circular countdown built from a conic gradient and a CSS mask, so progress is
  driven by a single `--progress` custom property. The ring reports progress only;
  it is not draggable, so the time cannot be knocked out of place by a stray click.
- Three modes with editable durations: **Focus** (60 min), **Short Break** (5 min)
  and **Long Break** (15 min). A long break is suggested after every 4 focus rounds.
- **Themes** instead of a task list — "What are you working on today?". Elapsed
  focus time is credited to the selected theme, so you can see where the hours went.
- A chime when a session ends, the remaining time in the tab title, and a
  full-screen mode that scales the ring up rather than just stretching the page.
- Every focus stretch is logged when it ends, whether it ran out or you stopped it,
  so an interruption is banked honestly rather than lost. Anything under a minute is
  a false start and is not recorded.

### Insights

- Daily, weekly, monthly and yearly totals, all computed from the log when the page
  is drawn rather than stored, so no figure can disagree with the record.
- A chart of recent periods. Each theme wears a colour, taken in the order themes
  first appear in the log, and a bar is stacked by theme in that same order, so a
  theme sits at the same height from one bar to the next.
- Pointing at a bar shows what it was made of. The breakdown is worked out once per
  change and kept, so pointing along the chart is a lookup rather than another walk
  through the log. The label sits above the bar and is half see-through, so neither
  the bar nor the pointer is hidden by the thing explaining them.
- Bars keep one width whatever the period is — at most 34px, with the leftover width
  going into the gaps, and each gap belonging to the bar beside it so there is no
  dead space to point at.
- **Add untracked time** records focus time spent away from the timer. It becomes an
  ordinary session; the form says what it will add, and mentions an overlap or a
  stretch running past midnight rather than refusing it.

### Sticky notes

- Draggable, resizable notes in six colours, organised into folders.
- Each note records its creation time, shown on the note and in full on hover.
- **Organise** lays the folder out in columns with every note collapsed to its top
  bar and first line; hovering or focusing one opens it above its neighbours.
  **Expand all** goes back to the open board.
- **Save as PNG** — a single note, or the whole board as it is arranged. Files are
  named after the timestamp (`2026-09-19_15-50-44.png`): the note's creation time
  for one note, the moment of export for a board.
- **Save as Word** — compiles the folder into one document, oldest note first, each
  with its first line as a heading and its full timestamp beneath, separated by
  horizontal rules.

### Everywhere

- Six background themes (four dark, two light) in the topbar. Each defines the whole
  token set, not just the background, so the light ones stay readable.
- The timer keeps running when you switch pages — every page stays mounted.

## Keyboard

| Key | Action |
| --- | --- |
| `Space` | Start / pause the timer (on the timer page) |
| `F` | Toggle full screen |
| Arrow keys | Move the focused note (hold `Shift` for larger steps) |
| `Alt` + arrows | Resize the focused note |
| `Escape` | Close the folder-name field or the background menu |

Note shortcuts apply when a note's drag bar or resize handle has focus, so the board
is usable without a pointer.

## Running it

```bash
npm install
npm run dev
```

Then open http://localhost:5173.

| Script | What it does |
| --- | --- |
| `npm run dev` | Dev server with hot reload |
| `npm run build` | Production bundle into `dist/` |
| `npm run preview` | Serve the built bundle locally |
| `npm test` | Run the checks (`checks.mjs`) |

## Storage

State is kept in `localStorage` under four keys. A browser cannot write to a folder
you choose and keep it up to date, which is why the native apps exist; here the
session log lives under its own key instead of in a file.

| Key | Holds |
| --- | --- |
| `tracker-tool.state.v1` | Durations, themes, completed rounds |
| `tracker-tool.sessions.v1` | The session log |
| `tracker-tool.notes.v1` | Folders, notes, board layout |
| `tracker-tool.background.v1` | Selected background theme |

The session log holds the same six fields as the native apps' `sessions.csv` —
`date,start,end,minutes,theme,completed` — in the same order, and **Download sessions.csv**
on the Insights page writes exactly that file, so a log started here opens in the
Mac or Windows app. It is append-only in the same way: a row is added when a stretch
ends and nothing is rewritten.

Clearing site data resets the app. Nothing leaves the browser.

## Project layout

```
src/
  App.jsx              Shell: topbar, routing, timer state, themes, the log
  TimerPage.jsx        The timer: modes, ring, controls, recording sessions
  TimerRing.jsx        The circular countdown (display only)
  Themes.jsx           "What are you working on today?"
  StatsPage.jsx        Insights: totals, the chart, the hover label, by theme
  ManualEntry.jsx      Adding focus time spent away from the timer
  Settings.jsx         Duration editor
  NotesPage.jsx        Board state, folders, toolbar, exports
  StickyNote.jsx       One note: drag, resize, colour, delete
  exportPng.js         Canvas-drawn PNG export
  exportDoc.js         Word-compatible HTML export
  notes.js             Note constants, sizes, timestamp formatting
  constants.js         Modes, default durations, storage key
  sessions.js          The session log: rows, CSV, and the rules for manual entry
  stats.js             Totals, period breakdowns, colours, chart geometry
  backgrounds.js       Background themes
  useTimer.js          Countdown hook
  useFullscreen.js     Fullscreen API hook
  useHashRoute.js      Hash router
  ErrorBoundary.jsx    Crash screen
  styles.css           All styling
checks.mjs             The checks: `npm test`
```

## Notes on the build

The app has **no runtime dependencies beyond React**. Both exports are written by
hand to keep it that way: the PNG is drawn onto a canvas rather than screenshotting
the DOM, and the Word export is Word-compatible HTML with a `.doc` extension — a
real `.docx` would need a zip writer. Routing is a 15-line hash hook rather than a
router package.

Styling is plain CSS with custom properties. React writes values (`--progress`,
`--note-width`, `--note-color`); the stylesheet owns the geometry.

There is no test runner either. `checks.mjs` is a plain Node script of 50 checks
over `sessions.js` and `stats.js` — the log's round trip through CSV, the bucketing
behind every figure Insights shows, which theme gets which colour, how wide a bar is
and where the hover label lands, and the rules for time added by hand. It mirrors
the native apps' `focus-check`, so the three of them are held to the same arithmetic
rather than merely looking alike.
