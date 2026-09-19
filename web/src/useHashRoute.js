import { useEffect, useState } from 'react'

const read = () => window.location.hash.replace(/^#\/?/, '') || 'timer'

// Two pages is not worth a router dependency.
export function useHashRoute() {
  const [route, setRoute] = useState(read)

  useEffect(() => {
    const sync = () => setRoute(read())
    window.addEventListener('hashchange', sync)
    return () => window.removeEventListener('hashchange', sync)
  }, [])

  return route
}
