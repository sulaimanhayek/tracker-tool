import { useState } from 'react'

function formatTracked(seconds) {
  if (seconds < 60) return '0m'
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
}

export default function Themes({ themes, activeId, onAdd, onSelect, onRemove }) {
  const [draft, setDraft] = useState('')

  const submit = (event) => {
    event.preventDefault()
    const name = draft.trim()
    if (!name) return
    onAdd(name)
    setDraft('')
  }

  return (
    <section className="themes">
      <h2>What are you working on today?</h2>

      <form className="theme-form" onSubmit={submit}>
        <input
          type="text"
          value={draft}
          placeholder="Add a theme — e.g. Deep work, Writing, Research"
          onChange={(event) => setDraft(event.target.value)}
          maxLength={60}
        />
        <button type="submit" className="primary" disabled={!draft.trim()}>
          Add
        </button>
      </form>

      {themes.length === 0 ? (
        <p className="empty">No themes yet. Name one to start tracking where your focus goes.</p>
      ) : (
        <ul className="theme-list">
          {themes.map((theme) => (
            <li key={theme.id} className={theme.id === activeId ? 'theme active' : 'theme'}>
              <button className="theme-select" onClick={() => onSelect(theme.id)}>
                <span className="theme-name">{theme.name}</span>
                <span className="theme-time">{formatTracked(theme.seconds)}</span>
              </button>
              <button
                className="theme-remove"
                onClick={() => onRemove(theme.id)}
                aria-label={`Remove ${theme.name}`}
              >
                ×
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
