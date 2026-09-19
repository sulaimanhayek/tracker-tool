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

    const tick = () => {
      const left = Math.max(0, Math.round((deadline - Date.now()) / 1000))
      setRemaining(left)
      if (left === 0) {
        setDeadline(null)
        completeRef.current?.()
      }
    }

    const id = setInterval(tick, 250)
    tick()
    return () => clearInterval(id)
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
