import { useMemo, useState } from 'react'
import { firstOverlap, manualSession, problemWith } from './sessions'
import { formatDuration } from './stats'

const today = () => {
  const now = new Date()
  const two = (value) => String(value).padStart(2, '0')
  return `${now.getFullYear()}-${two(now.getMonth() + 1)}-${two(now.getDate())}`
}

/// Focus time that happened away from the timer. It is written as an ordinary
/// session, because the point of the log is what the day held, not which button
/// recorded it.
export default function ManualEntry({ themes, sessions, onAdd, onCancel }) {
  const [day, setDay] = useState(today)
  const [from, setFrom] = useState('09:00')
  const [to, setTo] = useState('10:00')
  const [theme, setTheme] = useState(themes[0]?.name ?? '')

  const entry = useMemo(() => manualSession(day, from, to, theme), [day, from, to, theme])
  const problem = problemWith(entry)
  const clash = problem ? null : firstOverlap(entry, sessions)
  const crossesMidnight = entry.end.getDate() !== entry.start.getDate()

  return (
    <form
      className="manual-entry"
      onSubmit={(event) => {
        event.preventDefault()
        if (!problem) onAdd(entry)
      }}
    >
      <div className="manual-fields">
        <label>
          Day
          <input type="date" value={day} max={today()} onChange={(event) => setDay(event.target.value)} />
        </label>
        <label>
          From
          <input type="time" value={from} onChange={(event) => setFrom(event.target.value)} />
        </label>
        <label>
          To
          <input type="time" value={to} onChange={(event) => setTo(event.target.value)} />
        </label>
        <label>
          Theme
          {themes.length === 0 ? (
            <input
              type="text"
              value={theme}
              placeholder="e.g. Writing"
              onChange={(event) => setTheme(event.target.value)}
            />
          ) : (
            <select value={theme} onChange={(event) => setTheme(event.target.value)}>
              {themes.map((option) => (
                <option key={option.id} value={option.name}>
                  {option.name}
                </option>
              ))}
            </select>
          )}
        </label>
      </div>

      <p className="manual-note">
        {problem ?? `Adds ${formatDuration(entry.seconds)} to ${theme || 'No theme'}.`}
        {!problem && crossesMidnight ? ' Runs past midnight into the next day.' : ''}
        {clash ? ' This overlaps something already logged.' : ''}
      </p>

      <div className="manual-actions">
        <button type="button" className="ghost small" onClick={onCancel}>
          Cancel
        </button>
        <button type="submit" className="primary" disabled={Boolean(problem)}>
          {problem ? 'Add' : `Add ${formatDuration(entry.seconds)}`}
        </button>
      </div>
    </form>
  )
}
