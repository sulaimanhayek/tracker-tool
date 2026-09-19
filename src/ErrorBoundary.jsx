import { Component } from 'react'

// A render crash used to leave the last painted DOM on screen, looking alive but
// reacting to nothing. This makes the failure visible instead.
export default class ErrorBoundary extends Component {
  state = { error: null }

  static getDerivedStateFromError(error) {
    return { error }
  }

  componentDidCatch(error, info) {
    console.error('Crash in the timer app:', error, info.componentStack)
  }

  render() {
    if (!this.state.error) return this.props.children

    return (
      <div className="crash">
        <div className="crash-card">
          <h1>The timer stopped responding</h1>
          <p>
            Something threw while rendering, so the app was torn down. Reloading usually
            fixes it — after a code change, it always does.
          </p>
          <pre className="crash-detail">{String(this.state.error?.message ?? this.state.error)}</pre>
          <button className="primary" onClick={() => window.location.reload()}>
            Reload
          </button>
        </div>
      </div>
    )
  }
}
