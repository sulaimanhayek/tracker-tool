import { useCallback, useEffect, useState } from 'react'

function activeElement() {
  return document.fullscreenElement ?? document.webkitFullscreenElement ?? null
}

async function requestFullscreen() {
  const target = document.documentElement
  const request = target.requestFullscreen ?? target.webkitRequestFullscreen
  if (!request) throw new Error('Fullscreen API unavailable')
  await request.call(target)
}

async function exitFullscreen() {
  const exit = document.exitFullscreen ?? document.webkitExitFullscreen
  if (exit) await exit.call(document)
}

// Real browser fullscreen when the page is allowed it. Some embedded contexts
// block the API outright, so fall back to an in-page immersive layout rather
// than leaving the button dead.
export function useFullscreen() {
  const [native, setNative] = useState(() => activeElement() !== null)
  const [fallback, setFallback] = useState(false)

  useEffect(() => {
    const sync = () => setNative(activeElement() !== null)
    document.addEventListener('fullscreenchange', sync)
    document.addEventListener('webkitfullscreenchange', sync)
    return () => {
      document.removeEventListener('fullscreenchange', sync)
      document.removeEventListener('webkitfullscreenchange', sync)
    }
  }, [])

  // Escape leaves native fullscreen on its own; mirror that for the fallback.
  useEffect(() => {
    if (!fallback) return
    const onKey = (event) => {
      if (event.key === 'Escape') setFallback(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [fallback])

  // If native fullscreen does eventually engage, drop the fallback layout.
  useEffect(() => {
    if (native) setFallback(false)
  }, [native])

  const toggle = useCallback(async () => {
    if (activeElement()) {
      await exitFullscreen()
      return
    }
    if (fallback) {
      setFallback(false)
      return
    }
    try {
      // Some embedders reject, and some return a promise that never settles, so
      // the outcome is decided by what actually happened rather than by await.
      await Promise.race([requestFullscreen(), new Promise((resolve) => setTimeout(resolve, 400))])
    } catch {
      // Handled by the check below.
    }
    if (!activeElement()) setFallback(true)
  }, [fallback])

  return { isFullscreen: native || fallback, nativeBlocked: fallback, toggle }
}
