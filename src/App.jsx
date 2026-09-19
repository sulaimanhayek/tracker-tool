import { useEffect, useState } from 'react'
import TimerPage from './TimerPage.jsx'
import NotesPage from './NotesPage.jsx'
import { useFullscreen } from './useFullscreen'
import { useHashRoute } from './useHashRoute'

const PAGES = [
  { route: 'timer', label: 'Timer' },
  { route: 'notes', label: 'Sticky Notes' }
]

export default function App() {
  const route = useHashRoute()
  const fullscreen = useFullscreen()
  const [mode, setMode] = useState('focus')
  const [completedFocus, setCompletedFocus] = useState(0)

  const onNotes = route === 'notes'

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

  const accent = onNotes ? 'mode-notes' : `mode-${mode}`

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
          {!onNotes && <span className="rounds">{completedFocus} focus sessions today</span>}
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
        active={!onNotes}
        mode={mode}
        setMode={setMode}
        completedFocus={completedFocus}
        setCompletedFocus={setCompletedFocus}
      />
      <NotesPage active={onNotes} />
    </div>
  )
}
