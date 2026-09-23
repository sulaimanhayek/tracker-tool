// Every figure the Insights page shows is computed here from the session log.
// Nothing is stored in rolled-up form, so the numbers cannot drift from the
// record — the same rule the native apps follow.

export const GRAINS = [
  { key: 'day', label: 'Daily', span: 14 },
  { key: 'week', label: 'Weekly', span: 12 },
  { key: 'month', label: 'Monthly', span: 12 },
  { key: 'year', label: 'Yearly', span: 5 }
]

export const grainByKey = (key) => GRAINS.find((grain) => grain.key === key) ?? GRAINS[0]

/// A session with no theme still has to be called something.
export const labelFor = (theme) => (theme ? theme : 'No theme')

export function startOf(date, grain) {
  const at = new Date(date)
  at.setHours(0, 0, 0, 0)
  if (grain === 'week') {
    // Weeks run Monday to Sunday, as they do in the native apps.
    const weekday = (at.getDay() + 6) % 7
    at.setDate(at.getDate() - weekday)
  }
  if (grain === 'month') at.setDate(1)
  if (grain === 'year') at.setMonth(0, 1)
  return at
}

export function shift(date, grain, periods) {
  const at = new Date(date)
  if (grain === 'day') at.setDate(at.getDate() + periods)
  if (grain === 'week') at.setDate(at.getDate() + periods * 7)
  if (grain === 'month') at.setMonth(at.getMonth() + periods)
  if (grain === 'year') at.setFullYear(at.getFullYear() + periods)
  return at
}

// Formatters are kept rather than made on demand: building one costs more than
// formatting with it, and the chart formats two labels per bar.
const formatters = new Map()

function format(date, options) {
  const key = JSON.stringify(options)
  let formatter = formatters.get(key)
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(undefined, options)
    formatters.set(key, formatter)
  }
  return formatter.format(date)
}

export function title(date, grain) {
  if (grain === 'day') return format(date, { weekday: 'short', day: 'numeric', month: 'short' })
  if (grain === 'week') return `w/c ${format(date, { day: 'numeric', month: 'short' })}`
  if (grain === 'month') return format(date, { month: 'long', year: 'numeric' })
  return format(date, { year: 'numeric' })
}

export function shortTitle(date, grain) {
  if (grain === 'day') return format(date, { weekday: 'narrow' })
  if (grain === 'week') return format(date, { day: 'numeric', month: 'short' })
  if (grain === 'month') return format(date, { month: 'short' })
  return format(date, { year: 'numeric' })
}

// The colours themes are drawn in. A theme is given its colour by the order it
// first appears in the log, so it keeps that colour as the log grows and two
// people looking at the same data see the same chart.
export const PALETTE = [
  '#f2766b', '#4aa3df', '#63c39b', '#e2b04a', '#a98bdc', '#ef8fb4',
  '#5bc0c7', '#c4a484', '#8fbf5e', '#e08a4c', '#7f8fd6', '#cf6f9b'
]

export const colourAt = (index) => PALETTE[((index % PALETTE.length) + PALETTE.length) % PALETTE.length]

export function themeOrder(sessions) {
  const order = []
  for (const session of sessions) {
    const theme = labelFor(session.theme)
    if (!order.includes(theme)) order.push(theme)
  }
  return order
}

/// The whole chart in one pass over the log: a bar per period, each split by
/// theme, with its labels already worked out. Pointing at a bar then costs a
/// lookup rather than another walk through every session ever logged.
export function breakdown(sessions, grainKey, now = new Date()) {
  const grain = grainByKey(grainKey)
  const current = startOf(now, grain.key)
  const order = themeOrder(sessions)

  const totals = new Map()
  for (const session of sessions) {
    const period = startOf(session.start, grain.key).getTime()
    const byTheme = totals.get(period) ?? new Map()
    const theme = labelFor(session.theme)
    byTheme.set(theme, (byTheme.get(theme) ?? 0) + session.seconds)
    totals.set(period, byTheme)
  }

  const periods = []
  for (let back = grain.span - 1; back >= 0; back -= 1) {
    const start = shift(current, grain.key, -back)
    const byTheme = totals.get(start.getTime()) ?? new Map()
    // Slices keep the palette's order rather than the day's, so a theme sits at
    // the same height from one bar to the next.
    const slices = [...byTheme.entries()]
      .map(([theme, seconds]) => ({ theme, seconds, colour: Math.max(0, order.indexOf(theme)) }))
      .sort((a, b) => a.colour - b.colour)

    periods.push({
      start,
      key: start.getTime(),
      title: title(start, grain.key),
      shortTitle: shortTitle(start, grain.key),
      seconds: slices.reduce((sum, slice) => sum + slice.seconds, 0),
      slices
    })
  }
  return periods
}

/// The split for one period — used for the "By theme" list, largest first.
export function byTheme(sessions, grainKey, now = new Date()) {
  const current = startOf(now, grainKey).getTime()
  const totals = new Map()
  for (const session of sessions) {
    if (startOf(session.start, grainKey).getTime() !== current) continue
    const theme = labelFor(session.theme)
    totals.set(theme, (totals.get(theme) ?? 0) + session.seconds)
  }
  return [...totals.entries()]
    .map(([theme, seconds]) => ({ theme, seconds }))
    .sort((a, b) => b.seconds - a.seconds)
}

export function total(sessions, grainKey, now = new Date()) {
  return byTheme(sessions, grainKey, now).reduce((sum, row) => sum + row.seconds, 0)
}

export function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  if (hours === 0) return `${minutes}m`
  return minutes === 0 ? `${hours}h` : `${hours}h ${minutes}m`
}

/// `2:05` — hours and minutes, for the tight rows of the hover label where
/// every line has to line up.
export function clock(seconds) {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  return `${hours}:${String(minutes).padStart(2, '0')}`
}

// How wide a bar is and how far apart bars sit. A bar is the same width in
// every period — five years would otherwise be five slabs while fourteen days
// are thin strips — and the width left over is shared between them so the chart
// still spans the page.
export const WIDEST_BAR = 34
export const TIGHTEST_GAP = 6

export function barWidth(count, chartWidth) {
  const bars = Math.max(count, 1)
  // Each bar carries its own gap, so a cramped chart still fits.
  return Math.max(2, Math.min(WIDEST_BAR, chartWidth / bars - TIGHTEST_GAP))
}

/// The gap belongs to the column rather than sitting between columns, so the
/// columns tile the chart and pointing anywhere above a gap picks the bar next
/// to it.
export function gap(count, chartWidth, width) {
  const bars = Math.max(count, 1)
  return Math.max(TIGHTEST_GAP, chartWidth / bars - width)
}

// Where the hover label sits. It goes above the bar it describes rather than
// over it, so neither the bar nor the pointer is hidden by the thing explaining
// them.
export const LABEL_CLEARANCE = 8

export function labelHeight(rows) {
  const heading = 15
  const line = 15
  // No rows means one line saying there is nothing to show.
  return 16 + heading + (rows === 0 ? line : rows * line + line)
}

export function labelTop(barHeight, chartHeight, height) {
  return Math.max(0, chartHeight - barHeight - LABEL_CLEARANCE - height)
}
