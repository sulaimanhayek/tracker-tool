import { useCallback, useEffect, useRef, useState } from 'react'

const QUOTE_API = 'https://dummyjson.com/quotes/random'
const FADE_MS = 320

// Used when the network or the API is unavailable, so the header is never empty.
const FALLBACK_QUOTES = [
  { quote: 'It always seems impossible until it is done.', author: 'Nelson Mandela' },
  { quote: 'Well begun is half done.', author: 'Aristotle' },
  { quote: 'Amateurs sit and wait for inspiration, the rest of us just get up and go to work.', author: 'Stephen King' },
  { quote: 'The secret of getting ahead is getting started.', author: 'Mark Twain' },
  { quote: 'Simplicity is the ultimate sophistication.', author: 'Leonardo da Vinci' },
  { quote: 'You do not rise to the level of your goals, you fall to the level of your systems.', author: 'James Clear' },
  { quote: 'Concentrate all your thoughts upon the work at hand.', author: 'Alexander Graham Bell' }
]

function randomFallback(previous) {
  const options = FALLBACK_QUOTES.filter((item) => item.quote !== previous)
  return options[Math.floor(Math.random() * options.length)]
}

export default function Quote() {
  const [quote, setQuote] = useState(null)
  const [visible, setVisible] = useState(false)
  const [loading, setLoading] = useState(false)
  const mounted = useRef(true)
  const currentText = useRef(null)

  useEffect(() => {
    // Re-arm on every mount: StrictMode mounts, unmounts, then mounts again.
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])

  const fetchQuote = useCallback(async () => {
    try {
      const response = await fetch(QUOTE_API, { cache: 'no-store' })
      if (!response.ok) throw new Error(`Quote API returned ${response.status}`)
      const data = await response.json()
      if (!data?.quote) throw new Error('Unexpected quote payload')
      return { quote: data.quote, author: data.author ?? 'Unknown' }
    } catch {
      return randomFallback(currentText.current)
    }
  }, [])

  const load = useCallback(
    async (isFirst) => {
      setLoading(true)
      if (!isFirst) {
        // Fade the old quote out before swapping the text in.
        setVisible(false)
        await new Promise((resolve) => setTimeout(resolve, FADE_MS))
      }
      const next = await fetchQuote()
      if (!mounted.current) return
      currentText.current = next.quote
      setQuote(next)
      setVisible(true)
      setLoading(false)
    },
    [fetchQuote]
  )

  useEffect(() => {
    load(true)
  }, [load])

  return (
    <div className="quote">
      <blockquote className={visible ? 'quote-body visible' : 'quote-body'}>
        <p className="quote-text">“{quote?.quote ?? ''}”</p>
        <cite className="quote-author">{quote?.author ?? ''}</cite>
      </blockquote>

      <button
        className={loading ? 'quote-sync spinning' : 'quote-sync'}
        onClick={() => load(false)}
        disabled={loading}
        aria-label="Show another quote"
        title="Show another quote"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M21 12a9 9 0 0 1-9 9 9 9 0 0 1-7.5-4" />
          <path d="M3 12a9 9 0 0 1 9-9 9 9 0 0 1 7.5 4" />
          <polyline points="21 3 19.5 7 15.5 7" />
          <polyline points="3 21 4.5 17 8.5 17" />
        </svg>
      </button>
    </div>
  )
}
