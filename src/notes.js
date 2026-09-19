export const NOTE_SIZE = 240

export const NOTE_COLORS = [
  { key: 'amber', label: 'Amber', value: '#ffd45e' },
  { key: 'pink', label: 'Pink', value: '#ff9ec4' },
  { key: 'mint', label: 'Mint', value: '#8fe3c0' },
  { key: 'sky', label: 'Sky', value: '#8ecbff' },
  { key: 'lilac', label: 'Lilac', value: '#c3a7ff' },
  { key: 'lime', label: 'Lime', value: '#d8e86b' }
]

export const NOTE_INK = '#2c2820'

export const NOTES_STORAGE_KEY = 'tracker-tool.notes.v1'

// Collapsed height of a stacked note: its top bar plus the first line of text.
export const STACK_PEEK = 62
export const STACK_STEP_Y = 72
export const STACK_GAP_X = 24

export function colorValue(key) {
  return (NOTE_COLORS.find((color) => color.key === key) ?? NOTE_COLORS[0]).value
}

// Short enough to sit inside a 240px note; the full date goes in the tooltip.
export function formatStamp(createdAt) {
  if (!createdAt) return ''
  const date = new Date(createdAt)
  const sameYear = date.getFullYear() === new Date().getFullYear()
  return date.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    year: sameYear ? undefined : 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  })
}

export function formatStampLong(createdAt) {
  if (!createdAt) return ''
  return new Date(createdAt).toLocaleString(undefined, { dateStyle: 'full', timeStyle: 'short' })
}

// Sortable, filesystem-safe local timestamp: 2026-09-19_15-50-44
export function stampFilename(ms) {
  const date = new Date(ms ?? Date.now())
  const pad = (value) => String(value).padStart(2, '0')
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `_${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}`
  )
}

export const MIN_NOTE_WIDTH = 160
export const MIN_NOTE_HEIGHT = 150

// Notes created before resizing existed carry no size of their own.
export function noteSize(note) {
  return { width: note.width ?? NOTE_SIZE, height: note.height ?? NOTE_SIZE }
}
