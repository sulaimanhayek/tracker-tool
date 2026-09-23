import { useEffect, useMemo, useRef, useState } from 'react'
import BackgroundPicker from './BackgroundPicker.jsx'
import TimerPage from './TimerPage.jsx'
import NotesPage from './NotesPage.jsx'
import StatsPage from './StatsPage.jsx'
import { useFullscreen } from './useFullscreen'
import { useHashRoute } from './useHashRoute'
import { BACKGROUND_STORAGE_KEY, backgroundByKey } from './backgrounds'
import { DEFAULT_DURATIONS, STORAGE_KEY } from './constants'
import { loadRows, row, saveRows, session } from './sessions'

const PAGES = [
  { route: 'timer', label: 'Timer' },
  { route: 'notes', label: 'Sticky Notes' },
  { route: 'stats', label: 'Insights' }
]

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export default function App() {
  const route = useHashRoute()
  const fullscreen = useFullscreen()
  const saved = useRef(loadState()).current
  const [mode, setMode] = useState('focus')
  const [completedFocus, setCompletedFocus] = useState(saved?.completedFocus ?? 0)
  const [durations, setDurations] = useState(saved?.durations ?? DEFAULT_DURATIONS)
  // Themes and the log live here rather than on the timer page, because Insights
  // reads both and the timer page is only one of the two things writing to them.
  const [themes, setThemes] = useState(saved?.themes ?? [])
  const [activeThemeId, setActiveThemeId] = useState(saved?.activeThemeId ?? null)
  const [rows, setRows] = useState(loadRows)
  const [background, setBackground] = useState(() => {
    try {
      return localStorage.getItem(BACKGROUND_STORAGE_KEY) ?? 'midnight'
    } catch {
      return 'midnight'
    }
  })

  // The tokens go on the root element so the body background follows too.
  useEffect(() => {
    const theme = backgroundByKey(background)
    const root = document.documentElement
    Object.entries(theme.vars).forEach(([name, value]) => root.style.setProperty(name, value))
    root.style.colorScheme = theme.scheme
    try {
      localStorage.setItem(BACKGROUND_STORAGE_KEY, theme.key)
    } catch {
      // Storage can be unavailable (private mode); the colour still applies.
    }
  }, [background])

  useEffect(() => {
    const state = { durations, themes, activeThemeId, completedFocus }
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    } catch {
      // Storage can be unavailable (private mode); the app still works in memory.
    }
  }, [durations, themes, activeThemeId, completedFocus])

  useEffect(() => saveRows(rows), [rows])

  // The log is kept as rows, in the shape the file has, and read into dates once
  // rather than on every redraw of the chart.
  const sessions = useMemo(() => rows.map(session), [rows])

  const logSession = (start, end, theme, completed) =>
    setRows((current) => [...current, row(start, end, theme, completed)])

  const onNotes = route === 'notes'
  const onStats = route === 'stats'

  useEffect(() => {
    const onKey = (event) => {
      const tag = event.target.tagName
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'BUTTON') return
      if (event.key !== 'f' && event.key !== 'F') return
      event.preventDefault()
      fullscreen.toggle()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [fullscreen])

  useEffect(() => {
    if (onNotes) document.title = 'Sticky Notes'
  }, [onNotes])

  const accent = onNotes || onStats ? 'mode-notes' : `mode-${mode}`

  return (
    <div className={`app ${accent}${fullscreen.isFullscreen ? ' is-fullscreen' : ''}`}>
      <header className="topbar">
        <div className="topbar-left">
          <span className="brand">Focus</span>
          <nav className="page-nav">
            {PAGES.map((page) => (
              <a
                key={page.route}
                href={`#/${page.route}`}
                className={route === page.route ? 'page-link active' : 'page-link'}
                aria-current={route === page.route ? 'page' : undefined}
              >
                {page.label}
              </a>
            ))}
          </nav>
        </div>

        <div className="topbar-right">
          {!onNotes && !onStats && <span className="rounds">{completedFocus} focus sessions today</span>}
          <BackgroundPicker value={background} onChange={setBackground} />
          <button
            className="icon-button"
            onClick={fullscreen.toggle}
            aria-pressed={fullscreen.isFullscreen}
            title={fullscreen.isFullscreen ? 'Exit full screen (F)' : 'Full screen (F)'}
            aria-label={fullscreen.isFullscreen ? 'Exit full screen' : 'Enter full screen'}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              {fullscreen.isFullscreen ? (
                <>
                  <polyline points="9 3 9 9 3 9" />
                  <polyline points="15 3 15 9 21 9" />
                  <polyline points="15 21 15 15 21 15" />
                  <polyline points="9 21 9 15 3 15" />
                </>
              ) : (
                <>
                  <polyline points="3 9 3 3 9 3" />
                  <polyline points="21 9 21 3 15 3" />
                  <polyline points="21 15 21 21 15 21" />
                  <polyline points="3 15 3 21 9 21" />
                </>
              )}
            </svg>
          </button>
        </div>
      </header>

      {/* Both pages stay mounted so a running timer survives a page switch;
          the inactive one is only hidden. */}
      <TimerPage
        active={!onNotes && !onStats}
        mode={mode}
        setMode={setMode}
        completedFocus={completedFocus}
        setCompletedFocus={setCompletedFocus}
        durations={durations}
        setDurations={setDurations}
        themes={themes}
        setThemes={setThemes}
        activeThemeId={activeThemeId}
        setActiveThemeId={setActiveThemeId}
        onSession={logSession}
      />
      <NotesPage active={onNotes} />
      <StatsPage
        active={onStats}
        rows={rows}
        sessions={sessions}
        themes={themes}
        onAdd={(entry) => logSession(entry.start, entry.end, entry.theme, true)}
      />
    </div>
  )
}
