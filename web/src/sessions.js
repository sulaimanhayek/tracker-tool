// The session log: one row per stretch of focus, appended and never rewritten.
//
// A row holds the same six fields as the `sessions.csv` the Mac and Windows apps
// keep, in the same order, so what the browser records can be downloaded as that
// file and read by either of them.

export const SESSIONS_KEY = 'tracker-tool.sessions.v1'

export const CSV_HEADER = 'date,start,end,minutes,theme,completed'

/// A stretch shorter than this is a false start, not work, and is not logged.
export const SHORTEST_SESSION_SECONDS = 60

const two = (value) => String(value).padStart(2, '0')

export const dateField = (date) =>
  `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}`

export const timeField = (date) =>
  `${two(date.getHours())}:${two(date.getMinutes())}:${two(date.getSeconds())}`

/// A row as it would be written to the file.
export function row(start, end, theme, completed = true) {
  return {
    date: dateField(start),
    start: timeField(start),
    end: timeField(end),
    minutes: Math.round((end - start) / 60000),
    theme: theme ?? '',
    completed: Boolean(completed)
  }
}

/// A row read back as dates and seconds, which is what the charts work in.
export function session(record) {
  const start = new Date(`${record.date}T${record.start}`)
  let end = new Date(`${record.date}T${record.end}`)
  // A finish before its start crossed midnight — the same reading the native
  // apps give such a row.
  if (end <= start) end = new Date(end.getTime() + 24 * 60 * 60 * 1000)
  return {
    start,
    end,
    seconds: Math.round((end - start) / 1000),
    theme: record.theme ?? '',
    completed: Boolean(record.completed)
  }
}

export function loadRows() {
  try {
    const raw = localStorage.getItem(SESSIONS_KEY)
    const rows = raw ? JSON.parse(raw) : []
    return Array.isArray(rows) ? rows : []
  } catch {
    return []
  }
}

export function saveRows(rows) {
  try {
    localStorage.setItem(SESSIONS_KEY, JSON.stringify(rows))
  } catch {
    // Storage can be unavailable (private mode); the figures still hold for
    // this visit.
  }
}

export const toCsv = (rows) =>
  [CSV_HEADER, ...rows.map((r) => [r.date, r.start, r.end, r.minutes, r.theme, r.completed].join(','))]
    .join('\n') + '\n'

// Focus time that happened away from the timer, entered by hand. A manual row is
// an ordinary session — same six fields — because the point of the log is what
// the day held, not which button recorded it.

export const LONGEST_MANUAL_SECONDS = 12 * 60 * 60

/// Builds the session from the day picked and two clock times.
export function manualSession(day, from, to, theme) {
  const start = new Date(`${day}T${from}:00`)
  let end = new Date(`${day}T${to}:00`)
  if (end <= start) end = new Date(end.getTime() + 24 * 60 * 60 * 1000)
  return { start, end, seconds: Math.round((end - start) / 1000), theme: theme ?? '', completed: true }
}

/// What is wrong with the entry, in words the form can show, or null if it can
/// be saved. Time yet to happen is refused: the log is a record, not a plan.
export function problemWith(entry, now = new Date()) {
  if (!entry || Number.isNaN(entry.seconds)) return 'Fill in both times.'
  if (entry.seconds < 60) return 'That is less than a minute.'
  if (entry.seconds > LONGEST_MANUAL_SECONDS) {
    return `That is longer than ${LONGEST_MANUAL_SECONDS / 3600} hours — check the times.`
  }
  if (entry.end.getTime() > now.getTime() + 60000) return 'That time has not happened yet.'
  return null
}

/// Whether two stretches cover any of the same minutes. Overlapping entries are
/// allowed — they are only worth mentioning, since double-counting an hour is
/// usually a slip rather than a decision.
export const overlaps = (a, b) => a.start < b.end && b.start < a.end

export const firstOverlap = (entry, sessions) => sessions.find((other) => overlaps(entry, other)) ?? null
