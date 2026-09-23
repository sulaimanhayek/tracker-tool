import { useCallback, useEffect, useRef, useState } from 'react'

// Countdown driven by a wall-clock deadline so it stays accurate when the tab
// is throttled or backgrounded. `deadline === null` means paused/stopped.
export function useTimer(totalSeconds, onComplete) {
  const [remaining, setRemaining] = useState(totalSeconds)
  const [deadline, setDeadline] = useState(null)
  const completeRef = useRef(onComplete)

  useEffect(() => {
    completeRef.current = onComplete
  }, [onComplete])

  // A new duration (mode switch or settings change) resets the clock.
  useEffect(() => {
    setDeadline(null)
    setRemaining(totalSeconds)
  }, [totalSeconds])

  useEffect(() => {
    if (deadline === null) return

    let id = 0

    // One wake-up at a time, aimed at the moment the digit on screen changes,
    // rather than four a second whether or not anything moved. A hidden tab gets
    // a single wake-up for the whole remaining stretch: nothing is on screen to
    // update, and the deadline is wall-clock, so it catches up exactly.
    const tick = () => {
      clearTimeout(id)
      const left = Math.max(0, Math.round((deadline - Date.now()) / 1000))
      setRemaining(left)
      if (left === 0) {
        setDeadline(null)
        completeRef.current?.()
        return
      }
      const untilDigit = deadline - Date.now() - (left - 0.5) * 1000
      const delay = document.hidden ? deadline - Date.now() : untilDigit
      id = setTimeout(tick, Math.max(50, delay))
    }

    tick()
    document.addEventListener('visibilitychange', tick)
    return () => {
      clearTimeout(id)
      document.removeEventListener('visibilitychange', tick)
    }
  }, [deadline])

  const start = useCallback(() => {
    const seconds = remaining > 0 ? remaining : totalSeconds
    setRemaining(seconds)
    setDeadline(Date.now() + seconds * 1000)
  }, [remaining, totalSeconds])

  const pause = useCallback(() => setDeadline(null), [])

  // Scrubbing the ring: jump to an arbitrary point, keeping the clock running
  // if it already was.
  const reset = useCallback(() => {
    setDeadline(null)
    setRemaining(totalSeconds)
  }, [totalSeconds])

  const running = deadline !== null

  const toggle = useCallback(() => {
    running ? pause() : start()
  }, [running, pause, start])

  return { remaining, running, start, pause, reset, toggle }
}
