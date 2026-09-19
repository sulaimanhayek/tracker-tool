import { useEffect, useRef, useState } from 'react'
import { BACKGROUNDS } from './backgrounds'

export default function BackgroundPicker({ value, onChange }) {
  const [open, setOpen] = useState(false)
  const wrap = useRef(null)

  // Close on an outside click or Escape, the way a small popover should.
  useEffect(() => {
    if (!open) return
    const onDown = (event) => {
      if (!wrap.current?.contains(event.target)) setOpen(false)
    }
    const onKey = (event) => event.key === 'Escape' && setOpen(false)
    window.addEventListener('pointerdown', onDown)
    window.addEventListener('keydown', onKey)
    return () => {
      window.removeEventListener('pointerdown', onDown)
      window.removeEventListener('keydown', onKey)
    }
  }, [open])

  return (
    <div className="bg-picker" ref={wrap}>
      <button
        className="icon-button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-haspopup="true"
        title="Background colour"
        aria-label="Background colour"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="9" />
          <path d="M12 3a9 9 0 0 0 0 18 3 3 0 0 0 0-6 3 3 0 0 1 0-6 3 3 0 0 0 0-6Z" />
        </svg>
      </button>

      {open && (
        <div className="bg-menu" role="menu" aria-label="Background colour">
          {BACKGROUNDS.map((background) => (
            <button
              key={background.key}
              role="menuitemradio"
              aria-checked={background.key === value}
              className={background.key === value ? 'bg-option active' : 'bg-option'}
              onClick={() => {
                onChange(background.key)
                setOpen(false)
              }}
            >
              <span
                className="bg-chip"
                style={{
                  background: background.vars['--bg'],
                  borderColor: background.vars['--border']
                }}
                aria-hidden="true"
              />
              {background.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
