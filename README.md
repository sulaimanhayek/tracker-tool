# Focus

A Pomodoro timer and sticky-notes board that keeps its data as plain files on your
own machine — no database, no account, no sync.

This repository holds two apps:

| Folder | What it is | Status |
| --- | --- | --- |
| [`mac/`](mac) | Native macOS app (Swift + SwiftUI) | In progress |
| [`web/`](web) | The original React app | Working, feature-complete |

## Why two

The web app came first and still runs anywhere, but a browser cannot write to a
folder you choose and keep it up to date — Safari does not implement the File System
Access API, so an installed web app is limited to one-off downloads. The Mac app
exists to own a folder on disk.

The web app stays as it is, both as a reference implementation and because it works.

## The data

Everything lives in a single folder, readable and editable without the app:

```
~/Documents/Focus/
  sessions.csv          append-only, one row per focus session
  themes.json           the list of themes
  notes/<folder>/<timestamp>.doc
```

`sessions.csv` is a log, not a report: one row is appended when a session ends and
nothing is ever rewritten, so a crash costs at most one row. Daily, weekly, monthly
and yearly figures are computed in the app from that log rather than stored, which
keeps the file append-only and means the numbers can never drift from the record.

Open it in Numbers or Excel whenever you want your own view of it.

## Getting started

- **Mac app** — see [`mac/README.md`](mac/README.md)
- **Web app** — see [`web/README.md`](web/README.md)

## Branching

`main` is the released branch and `dev` is the working branch. Changes go through a
pull request from `dev` into `main`.
