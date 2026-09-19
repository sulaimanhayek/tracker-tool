import { useCallback, useEffect, useRef, useState } from 'react'
import Quote from './Quote.jsx'
import TimerRing from './TimerRing.jsx'
import Themes from './Themes.jsx'
import Settings from './Settings.jsx'
import { useTimer } from './useTimer'
import {
  DEFAULT_DURATIONS,
  MODES,
  MODE_ORDER,
  ROUNDS_BEFORE_LONG_BREAK,
  STORAGE_KEY
} from './constants'

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    return JSON.parse(raw)
  } catch {
    return null
  }
}

function chime() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.frequency.value = 660
    gain.gain.setValueAtTime(0.0001, ctx.currentTime)
    gain.gain.exponentialRampToValueAtTime(0.2, ctx.currentTime + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 1.2)
    osc.connect(gain).connect(ctx.destination)
    osc.start()
    osc.stop(ctx.currentTime + 1.3)
    osc.onended = () => ctx.close()
  } catch {
    // Audio is a nicety; never let it break the timer.
  }
}

export default function TimerPage({ active, mode, setMode, completedFocus, setCompletedFocus }) {
  const saved = useRef(loadState()).current

  const [durations, setDurations] = useState(saved?.durations ?? DEFAULT_DURATIONS)
  const [themes, setThemes] = useState(saved?.themes ?? [])
  const [activeThemeId, setActiveThemeId] = useState(saved?.activeThemeId ?? null)
  const [showSettings, setShowSettings] = useState(false)

  const totalSeconds = durations[mode] * 60
  const activeTheme = themes.find((theme) => theme.id === activeThemeId) ?? null

  const handleComplete = useCallback(() => {
    chime()
    if (mode !== 'focus') {
      setMode('focus')
      return
    }
    const rounds = completedFocus + 1
    setCompletedFocus(rounds)
    setMode(rounds % ROUNDS_BEFORE_LONG_BREAK === 0 ? 'long' : 'short')
  }, [mode, completedFocus, setMode, setCompletedFocus])

  const { remaining, running, reset, toggle } = useTimer(totalSeconds, handleComplete)

  // Credit elapsed focus time to the selected theme.
  const previousRemaining = useRef(remaining)
  useEffect(() => {
    const elapsed = previousRemaining.current - remaining
    previousRemaining.current = remaining
    if (!running || mode !== 'focus' || elapsed <= 0 || elapsed > 2 || !activeThemeId) return
    setThemes((current) =>
      current.map((theme) =>
        theme.id === activeThemeId ? { ...theme, seconds: theme.seconds + elapsed } : theme
      )
    )
  }, [remaining, running, mode, activeThemeId])

  useEffect(() => {
    const state = { durations, themes, activeThemeId, completedFocus }
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    } catch {
      // Storage can be unavailable (private mode); the app still works in memory.
    }
  }, [durations, themes, activeThemeId, completedFocus])

  useEffect(() => {
    if (!active) return
    document.title = `${MODES[mode].label} · ${Math.ceil(remaining / 60)}m`
  }, [active, mode, remaining])

  useEffect(() => {
    if (!active) return
    const onKey = (event) => {
      const tag = event.target.tagName
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'BUTTON') return
      if (event.code !== 'Space') return
      event.preventDefault()
      toggle()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [active, toggle])

  const addTheme = (name) => {
    const theme = { id: crypto.randomUUID(), name, seconds: 0 }
    setThemes((current) => [...current, theme])
    setActiveThemeId((current) => current ?? theme.id)
  }

  const removeTheme = (id) => {
    setThemes((current) => current.filter((theme) => theme.id !== id))
    setActiveThemeId((current) => (current === id ? null : current))
  }

  const changeDuration = (key, value) => {
    const minutes = Math.min(480, Math.max(1, Number(value) || 1))
    setDurations((current) => ({ ...current, [key]: minutes }))
  }

  return (
    <main className="main" hidden={!active}>
      <Quote />

      <nav className="tabs" role="tablist">
        {MODE_ORDER.map((key) => (
          <button
            key={key}
            role="tab"
            aria-selected={mode === key}
            className={mode === key ? 'tab active' : 'tab'}
            onClick={() => setMode(key)}
          >
            {MODES[key].label}
          </button>
        ))}
      </nav>

      <TimerRing
        remaining={remaining}
        total={totalSeconds}
        running={running}
        theme={activeTheme?.name}
        onToggle={toggle}
        onReset={reset}
      />

      <button className="ghost small settings-toggle" onClick={() => setShowSettings((v) => !v)}>
        {showSettings ? 'Hide durations' : 'Change durations'}
      </button>

      {showSettings && (
        <Settings
          durations={durations}
          onChange={changeDuration}
          onReset={() => setDurations(DEFAULT_DURATIONS)}
        />
      )}

      <Themes
        themes={themes}
        activeId={activeThemeId}
        onAdd={addTheme}
        onSelect={setActiveThemeId}
        onRemove={removeTheme}
      />
    </main>
  )
}
