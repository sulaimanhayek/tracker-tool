# Focus

A Pomodoro timer and a sticky-notes board, in one small React app. No backend, no
accounts, no tracking — everything lives in the browser.

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
- The timer keeps running when you switch pages — both pages stay mounted.

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

## Storage

State is kept in `localStorage` under three keys, which is deliberately temporary —
real storage is still to be decided.

| Key | Holds |
| --- | --- |
| `tracker-tool.state.v1` | Durations, themes, completed rounds |
| `tracker-tool.notes.v1` | Folders, notes, board layout |
| `tracker-tool.background.v1` | Selected background theme |

Clearing site data resets the app. Nothing leaves the browser.

## Project layout

```
src/
  App.jsx              Shell: topbar, hash routing, background theme
  TimerPage.jsx        Timer state, themes, durations, persistence
  TimerRing.jsx        The circular countdown (display only)
  Themes.jsx           "What are you working on today?"
  Settings.jsx         Duration editor
  NotesPage.jsx        Board state, folders, toolbar, exports
  StickyNote.jsx       One note: drag, resize, colour, delete
  exportPng.js         Canvas-drawn PNG export
  exportDoc.js         Word-compatible HTML export
  notes.js             Note constants, sizes, timestamp formatting
  constants.js         Modes, default durations, storage key
  backgrounds.js       Background themes
  useTimer.js          Countdown hook
  useFullscreen.js     Fullscreen API hook
  useHashRoute.js      Two-page hash router
  ErrorBoundary.jsx    Crash screen
  styles.css           All styling
```

## Notes on the build

The app has **no runtime dependencies beyond React**. Both exports are written by
hand to keep it that way: the PNG is drawn onto a canvas rather than screenshotting
the DOM, and the Word export is Word-compatible HTML with a `.doc` extension — a
real `.docx` would need a zip writer. Routing is a 15-line hash hook rather than a
router package.

Styling is plain CSS with custom properties. React writes values (`--progress`,
`--note-width`, `--note-color`); the stylesheet owns the geometry.

## Branching

`main` is the released branch and `dev` is the working branch. Changes go through a
pull request from `dev` into `main`.
