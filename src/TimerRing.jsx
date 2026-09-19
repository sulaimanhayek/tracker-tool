function formatTime(totalSeconds) {
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  const pad = (n) => String(n).padStart(2, '0')
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(seconds)}` : `${pad(minutes)}:${pad(seconds)}`
}

export default function TimerRing({ remaining, total, running, theme, onToggle, onReset }) {
  const progress = total > 0 ? remaining / total : 0

  return (
    <div className="ring-wrap" style={{ '--progress': progress }}>
      {/* The ring and its marker only report progress — the time is changed with
          the controls, never by dragging. */}
      <div className="ring" aria-hidden="true" />
      <span className="ring-knob" aria-hidden="true" />

      <div className="ring-center">
        <div className="time" role="timer" aria-live="off">
          {formatTime(remaining)}
        </div>
        <div className="ring-theme">{theme ? theme : 'No theme selected'}</div>
        <div className="ring-actions">
          <button className="primary" onClick={onToggle}>
            {running ? 'Pause' : remaining === total ? 'Start' : 'Resume'}
          </button>
          <button className="ghost" onClick={onReset} disabled={remaining === total && !running}>
            Reset
          </button>
        </div>
      </div>
    </div>
  )
}
