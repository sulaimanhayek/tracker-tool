import { useCallback, useEffect, useRef, useState } from 'react'
import TimerRing from './TimerRing.jsx'
import Themes from './Themes.jsx'
import Settings from './Settings.jsx'
import { useTimer } from './useTimer'
import { SHORTEST_SESSION_SECONDS } from './sessions'
import { DEFAULT_DURATIONS, MODES, MODE_ORDER, ROUNDS_BEFORE_LONG_BREAK } from './constants'

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

export default function TimerPage({
  active,
  mode,
  setMode,
  completedFocus,
  setCompletedFocus,
  durations,
  setDurations,
  themes,
  setThemes,
  activeThemeId,
  setActiveThemeId,
  onSession
}) {
  const [showSettings, setShowSettings] = useState(false)

  const totalSeconds = durations[mode] * 60
  const activeTheme = themes.find((theme) => theme.id === activeThemeId) ?? null

  // One stretch of focus, from the moment the clock started running to the
  // moment it stopped. Breaks are not work, and a stretch too short to mean
  // anything is not worth a row in the log.
  const segmentStart = useRef(null)
  const themeName = activeTheme?.name ?? ''
  const record = useCallback(
    (completed) => {
      const started = segmentStart.current
      segmentStart.current = null
      if (!started || mode !== 'focus') return
      const end = new Date()
      if ((end - started) / 1000 < SHORTEST_SESSION_SECONDS) return
      onSession(started, end, themeName, completed)
    },
    [mode, themeName, onSession]
  )

  const handleComplete = useCallback(() => {
    record(true)
    chime()
    if (mode !== 'focus') {
      setMode('focus')
      return
    }
    const rounds = completedFocus + 1
    setCompletedFocus(rounds)
    setMode(rounds % ROUNDS_BEFORE_LONG_BREAK === 0 ? 'long' : 'short')
  }, [mode, completedFocus, setMode, setCompletedFocus, record])

  const { remaining, running, reset: clear, toggle: startOrPause } = useTimer(totalSeconds, handleComplete)

  useEffect(() => {
    if (running && !segmentStart.current) segmentStart.current = new Date()
  }, [running])

  const toggle = () => {
    if (running) record(false)
    startOrPause()
  }

  const reset = () => {
    record(false)
    clear()
  }

  const changeMode = (key) => {
    record(false)
    setMode(key)
  }

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
      <nav className="tabs" role="tablist">
        {MODE_ORDER.map((key) => (
          <button
            key={key}
            role="tab"
            aria-selected={mode === key}
            className={mode === key ? 'tab active' : 'tab'}
            onClick={() => changeMode(key)}
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
