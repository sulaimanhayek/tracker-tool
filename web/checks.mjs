// The web app's checks. Plain Node, no test runner — the same shape as the
// native apps' `focus-check` and `Focus.Check`, and for the same reason: the
// figures and the file format are worth holding still, and a dependency for
// that is a dependency to keep up to date.
//
//   npm test

import {
  GRAINS, barWidth, breakdown, byTheme, clock, colourAt, formatDuration, gap,
  labelHeight, labelTop, PALETTE, shortTitle, startOf, themeOrder, title, total,
  TIGHTEST_GAP, WIDEST_BAR
} from './src/stats.js'
import {
  CSV_HEADER, firstOverlap, manualSession, overlaps, problemWith, row, session, toCsv
} from './src/sessions.js'

let failures = 0

function check(what, passed) {
  console.log(`  ${passed ? 'ok  ' : 'FAIL'} ${what}`)
  if (!passed) failures += 1
}

const at = (text) => new Date(text)
const made = (start, end, theme) => ({
  start: at(start),
  end: at(end),
  seconds: Math.round((at(end) - at(start)) / 1000),
  theme,
  completed: true
})

console.log('\nThe shape of a row')
{
  const written = row(at('2026-09-20T09:00:00'), at('2026-09-20T09:25:00'), 'Writing')
  check('the columns are the ones the file has', Object.keys(written).join(',') === CSV_HEADER)
  check('minutes are the length, not a guess', written.minutes === 25)
  check('a row reads back as the stretch it recorded', session(written).seconds === 25 * 60)
  check('the csv keeps the header the other apps expect', toCsv([written]).split('\n')[0] === CSV_HEADER)
  check('one row per line, ending in a newline', toCsv([written]).split('\n').length === 3)

  const midnight = { date: '2026-09-20', start: '23:30:00', end: '00:15:00', minutes: 45, theme: '', completed: true }
  check('a finish before its start crossed midnight', session(midnight).seconds === 45 * 60)
}

console.log('\nTime added by hand')
{
  const now = at('2026-09-20T18:00:00')
  const entry = manualSession('2026-09-20', '09:00', '10:30', 'Reading')
  check('a hand-typed stretch is an ordinary session', entry.seconds === 90 * 60)
  check('and it can be saved', problemWith(entry, now) === null)
  check('a minute is the shortest worth recording', problemWith(manualSession('2026-09-20', '09:00', '09:00'), now) !== null)
  check('half a day is the longest', problemWith(manualSession('2026-09-20', '01:00', '14:00'), now) !== null)
  check('time yet to happen is refused', problemWith(manualSession('2026-09-20', '19:00', '20:00'), now) !== null)
  check('a night shift rolls past midnight', manualSession('2026-09-20', '23:00', '01:00').seconds === 2 * 3600)

  const logged = [made('2026-09-20T09:30:00', '2026-09-20T10:00:00', 'Writing')]
  check('an entry over one already logged is spotted', firstOverlap(entry, logged) !== null)
  check('ending exactly when the next begins is not', !overlaps(entry, made('2026-09-20T10:30:00', '2026-09-20T11:00:00', 'Writing')))
}

console.log('\nThe chart, in one pass')
{
  const monday = made('2026-09-21T09:00:00', '2026-09-21T10:00:00', 'Writing')
  const mondayAdmin = made('2026-09-21T11:00:00', '2026-09-21T11:30:00', 'Admin')
  const tuesday = made('2026-09-22T09:00:00', '2026-09-22T09:30:00', 'Admin')
  const sessions = [monday, mondayAdmin, tuesday]
  const now = at('2026-09-22T20:00:00')

  const order = themeOrder(sessions)
  check('themes are coloured in the order they first appear', order.join() === 'Writing,Admin')
  check('a theme named twice is only counted once', themeOrder([...sessions, ...sessions]).join() === order.join())
  check('an unnamed theme is still shown', themeOrder([made('2026-09-21T09:00:00', '2026-09-21T09:10:00', '')])[0] === 'No theme')
  check('the palette wraps rather than running out', colourAt(PALETTE.length) === PALETTE[0])

  const periods = breakdown(sessions, 'day', now)
  check('a bar per period', periods.length === GRAINS[0].span)
  check('the last bar is today', periods.at(-1).start.getTime() === startOf(now, 'day').getTime())
  check('each bar totals its sessions', periods.at(-1).seconds === 30 * 60)
  check('a bar is split by theme', periods.at(-2).slices.map((s) => s.theme).join() === 'Writing,Admin')
  check('its slices add up to the bar', periods.at(-2).slices.reduce((sum, s) => sum + s.seconds, 0) === periods.at(-2).seconds)
  check(
    'a theme keeps its colour from one bar to the next',
    periods.at(-2).slices.find((s) => s.theme === 'Admin').colour === periods.at(-1).slices[0].colour
  )
  check('an empty period has no slices', periods.some((period) => period.seconds === 0 && period.slices.length === 0))
  check('labels come ready to draw', periods.at(-1).title === title(periods.at(-1).start, 'day'))
  check('the short label is the one under the bar', periods.at(-1).shortTitle === shortTitle(periods.at(-1).start, 'day'))
  check('a week gathers the days in it', breakdown(sessions, 'week', now).at(-1).seconds === 2 * 3600)
  check('the headline is what the current period holds', total(sessions, 'day', now) === 30 * 60)
  check('the by-theme list puts the largest share first', byTheme(sessions, 'week', now)[0].theme === 'Writing')
}

console.log('\nWhat the figures read as')
{
  check('under an hour is minutes', formatDuration(45 * 60) === '45m')
  check('a round hour says so', formatDuration(3600) === '1h')
  check('and the rest is both', formatDuration(3600 + 45 * 60) === '1h 45m')
  check('the label clock shows hours and minutes', clock(45 * 60) === '0:45')
  check('it pads the minutes', clock(2 * 3600 + 5 * 60) === '2:05')
  check('seconds left over do not round the minute up', clock(59) === '0:00')
}

console.log('\nHow wide a bar is')
{
  const wide = barWidth(5, 900)
  const narrow = barWidth(14, 900)
  check('five years and fourteen days draw the same bar', wide === narrow)
  check('a bar is never wider than the limit', wide === WIDEST_BAR)
  check('bars narrow rather than overflow a small page', barWidth(14, 200) < WIDEST_BAR)
  check('a bar is never narrower than a hairline', barWidth(400, 50) >= 2)

  const spread = gap(5, 900, wide)
  check('the spare width goes into the gaps', 5 * (wide + spread) === 900)
  check('fewer bars means wider gaps', spread > gap(14, 900, narrow))
  check('a cramped chart still fits the page', 14 * (barWidth(14, 200) + gap(14, 200, barWidth(14, 200))) <= 200.001)
  check('gaps do not close up when there is no room', gap(14, 200, barWidth(14, 200)) - TIGHTEST_GAP < 0.001)
}

console.log('\nWhere the hover label sits')
{
  check('a label grows a line per theme', labelHeight(3) - labelHeight(2) === 15)
  check('an empty period still has a label to show', labelHeight(0) > 0)
  check('a total is counted in as well as the themes', labelHeight(1) > labelHeight(0))

  const height = labelHeight(2)
  const top = labelTop(30, 120, height)
  check('the label sits above the bar, not over it', top + height + 8 === 120 - 30)
  check('a taller bar pushes its label further up', labelTop(60, 120, height) < top)
  check('a bar with no room above it keeps the label on the chart', labelTop(120, 120, height) === 0)
}

console.log('')
if (failures === 0) {
  console.log('All checks passed.')
} else {
  console.log(`${failures} check(s) failed.`)
  process.exit(1)
}
