import { MODES, MODE_ORDER } from './constants'

export default function Settings({ durations, onChange, onReset }) {
  return (
    <section className="settings">
      <div className="settings-head">
        <h2>Durations</h2>
        <button className="ghost small" onClick={onReset}>
          Restore defaults
        </button>
      </div>

      <div className="settings-grid">
        {MODE_ORDER.map((key) => (
          <label key={key} className="field">
            <span>{MODES[key].label}</span>
            <span className="field-input">
              <input
                type="number"
                min="1"
                max="480"
                value={durations[key]}
                onChange={(event) => onChange(key, event.target.value)}
              />
              <span className="unit">min</span>
            </span>
          </label>
        ))}
      </div>
      <p className="hint">Changing a duration resets that timer.</p>
    </section>
  )
}
