import { useEffect, useMemo, useRef, useState } from 'react'
import ManualEntry from './ManualEntry.jsx'
import {
  GRAINS, barWidth, breakdown, byTheme, clock, colourAt, formatDuration, gap,
  labelHeight, labelTop, themeOrder, title, total
} from './stats'
import { toCsv } from './sessions'

const CHART_HEIGHT = 120

/// The width the chart actually has, watched rather than guessed, because the
/// bars are sized from it.
function useWidth() {
  const ref = useRef(null)
  const [width, setWidth] = useState(0)

  useEffect(() => {
    const node = ref.current
    if (!node) return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(node)
    setWidth(node.clientWidth)
    return () => observer.disconnect()
  }, [])

  return [ref, width]
}

export default function StatsPage({ active, rows, sessions, themes, onAdd }) {
  const [grain, setGrain] = useState('day')
  const [hovered, setHovered] = useState(null)
  const [adding, setAdding] = useState(false)
  const [chartRef, width] = useWidth()

  // The whole chart is worked out once and kept until the log or the period
  // changes, so pointing along the row of bars costs a lookup rather than
  // another walk through every session ever logged.
  const periods = useMemo(() => breakdown(sessions, grain), [sessions, grain])
  const themeTotals = useMemo(() => byTheme(sessions, grain), [sessions, grain])
  const order = useMemo(() => themeOrder(sessions), [sessions])

  const peak = Math.max(...periods.map((period) => period.seconds), 1)
  const bar = barWidth(periods.length, width || 600)
  const column = bar + gap(periods.length, width || 600, bar)
  const headline = total(sessions, grain)

  const legend = []
  for (const period of periods) {
    for (const slice of period.slices) {
      if (!legend.some((seen) => seen.theme === slice.theme)) legend.push(slice)
    }
  }
  legend.sort((a, b) => a.colour - b.colour)

  const download = () => {
    const blob = new Blob([toCsv(rows)], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = 'sessions.csv'
    link.click()
    URL.revokeObjectURL(url)
  }

  return (
    <main className="main stats" hidden={!active}>
      <nav className="tabs" role="tablist">
        {GRAINS.map((option) => (
          <button
            key={option.key}
            role="tab"
            aria-selected={grain === option.key}
            className={grain === option.key ? 'tab active' : 'tab'}
            onClick={() => setGrain(option.key)}
          >
            {option.label}
          </button>
        ))}
      </nav>

      <section className="stats-head">
        <div>
          <p className="stats-total">{formatDuration(headline)}</p>
          <p className="stats-period">{title(new Date(), grain)}</p>
        </div>
        <div className="stats-actions">
          <button className="ghost small" onClick={() => setAdding((open) => !open)}>
            {adding ? 'Close' : 'Add untracked time'}
          </button>
          <button className="ghost small" onClick={download} disabled={rows.length === 0}>
            Download sessions.csv
          </button>
        </div>
      </section>

      {adding && (
        <ManualEntry
          themes={themes}
          sessions={sessions}
          onAdd={(entry) => {
            onAdd(entry)
            setAdding(false)
          }}
          onCancel={() => setAdding(false)}
        />
      )}

      <div className="chart" ref={chartRef} style={{ height: `${CHART_HEIGHT + 20}px` }}>
        {periods.map((period, index) => {
          const height = Math.max(2, (CHART_HEIGHT * period.seconds) / peak)
          return (
            <div
              key={period.key}
              className="chart-column"
              style={{ width: `${column}px` }}
              // The column, gap and all, is the target — so a thin bar, a wide
              // gap or an empty period is as easy to point at as a tall bar.
              onMouseEnter={() => setHovered(index)}
              onMouseLeave={() => setHovered((current) => (current === index ? null : current))}
            >
              <div
                className={`chart-bar${hovered !== null && hovered !== index ? ' dimmed' : ''}`}
                style={{ width: `${bar}px`, height: `${height}px` }}
                title={`${period.title}: ${formatDuration(period.seconds)}`}
              >
                {period.slices.length === 0 ? (
                  <span className="chart-slice empty" style={{ height: '2px' }} />
                ) : (
                  // Stacked from the palette's order, so a theme sits at the same
                  // height from one bar to the next.
                  [...period.slices].reverse().map((slice) => (
                    <span
                      key={slice.theme}
                      className="chart-slice"
                      style={{
                        height: `${Math.max(1, (CHART_HEIGHT * slice.seconds) / peak)}px`,
                        background: colourAt(slice.colour)
                      }}
                    />
                  ))
                )}
              </div>
              <span className="chart-tick">{period.shortTitle}</span>
            </div>
          )
        })}

        {hovered !== null && (
          <HoverLabel
            period={periods[hovered]}
            left={column * (hovered + 0.5)}
            chartWidth={width}
            barHeight={Math.max(2, (CHART_HEIGHT * periods[hovered].seconds) / peak)}
          />
        )}
      </div>

      {legend.length > 0 && (
        <ul className="chart-legend">
          {legend.map((slice) => (
            <li key={slice.theme}>
              <span className="chart-swatch" style={{ background: colourAt(slice.colour) }} />
              {slice.theme}
            </li>
          ))}
        </ul>
      )}

      <section className="themes stats-themes">
        <h2>By theme</h2>
        {themeTotals.length === 0 ? (
          <p className="empty">Nothing logged in this period yet.</p>
        ) : (
          <ul className="theme-bars">
            {themeTotals.map((row) => (
              <li key={row.theme}>
                <span className="theme-bar-name">{row.theme}</span>
                <span className="theme-bar-track">
                  <span
                    className="theme-bar-fill"
                    style={{
                      width: `${Math.max(2, (100 * row.seconds) / themeTotals[0].seconds)}%`,
                      background: colourAt(Math.max(0, order.indexOf(row.theme)))
                    }}
                  />
                </span>
                <span className="theme-bar-time">{formatDuration(row.seconds)}</span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <p className="stats-count">{sessions.length} sessions logged</p>
    </main>
  )
}

/// The hover label: the period, its themes, the total. It sits above the bar it
/// describes rather than over it, so neither the bar nor the pointer is hidden
/// by the thing explaining them.
function HoverLabel({ period, left, chartWidth, barHeight }) {
  const WIDTH = 170
  const height = labelHeight(period.slices.length)
  const x = Math.min(Math.max(0, left - WIDTH / 2), Math.max(0, chartWidth - WIDTH))

  return (
    <div
      className="chart-label"
      style={{ left: `${x}px`, top: `${labelTop(barHeight, CHART_HEIGHT, height)}px`, width: `${WIDTH}px` }}
    >
      <p className="chart-label-head">{period.title}</p>
      {period.slices.length === 0 ? (
        <p className="chart-label-empty">Nothing logged</p>
      ) : (
        <>
          {period.slices.map((slice) => (
            <p key={slice.theme} className="chart-label-row">
              <span className="chart-swatch" style={{ background: colourAt(slice.colour) }} />
              <span className="chart-label-theme">{slice.theme}:</span>
              <span className="chart-label-time">{clock(slice.seconds)}</span>
            </p>
          ))}
          <p className="chart-label-total">TOTAL: {clock(period.seconds)}</p>
        </>
      )}
    </div>
  )
}
