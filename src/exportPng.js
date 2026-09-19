import { NOTE_COLORS, NOTE_INK, colorValue, formatStamp, noteSize } from './notes'

const PADDING = 48
const BOARD_BG = '#161a22'
const FONT = '16px ui-sans-serif, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif'
const LINE_HEIGHT = 24
const TEXT_INSET = 22

function wrap(ctx, text, maxWidth) {
  const lines = []
  for (const paragraph of text.split('\n')) {
    if (paragraph === '') {
      lines.push('')
      continue
    }
    let line = ''
    for (const word of paragraph.split(/\s+/)) {
      const candidate = line ? `${line} ${word}` : word
      if (ctx.measureText(candidate).width <= maxWidth || !line) {
        line = candidate
      } else {
        lines.push(line)
        line = word
      }
    }
    lines.push(line)
  }
  return lines
}

function drawNote(ctx, note, originX, originY) {
  const x = note.x - originX
  const y = note.y - originY
  const { width, height } = noteSize(note)

  ctx.save()
  ctx.translate(x + width / 2, y + height / 2)
  ctx.rotate((note.rotation * Math.PI) / 180)
  ctx.translate(-width / 2, -height / 2)

  ctx.shadowColor = 'rgba(0, 0, 0, 0.45)'
  ctx.shadowBlur = 18
  ctx.shadowOffsetY = 8
  ctx.fillStyle = colorValue(note.color)
  ctx.beginPath()
  ctx.roundRect(0, 0, width, height, 6)
  ctx.fill()
  ctx.shadowColor = 'transparent'

  ctx.fillStyle = NOTE_INK
  ctx.font = FONT
  ctx.textBaseline = 'top'
  const lines = wrap(ctx, note.text || '', width - TEXT_INSET * 2)
  const maxLines = Math.floor((height - TEXT_INSET * 2) / LINE_HEIGHT)
  lines.slice(0, maxLines).forEach((line, index) => {
    ctx.fillText(line, TEXT_INSET, TEXT_INSET + index * LINE_HEIGHT)
  })

  const stamp = formatStamp(note.createdAt)
  if (stamp) {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.45)'
    ctx.font = `11px ${FONT.split('px ')[1]}`
    ctx.textBaseline = 'alphabetic'
    ctx.fillText(stamp, TEXT_INSET, height - 16)
  }

  ctx.restore()
}

function download(canvas, filename) {
  canvas.toBlob((blob) => {
    if (!blob) return
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    link.click()
    // Revoking straight away can cancel the download before the browser has
    // picked the blob up.
    setTimeout(() => URL.revokeObjectURL(url), 10000)
  }, 'image/png')
}

// Notes are drawn onto a canvas directly rather than screenshotting the DOM, so
// the export needs no extra dependency and always looks the same.
export function exportNotesToPng(notes, filename) {
  if (notes.length === 0) return false

  // Rotation lets a note poke outside its box; the slop covers that.
  const slop = 24
  const minX = Math.min(...notes.map((note) => note.x)) - slop
  const minY = Math.min(...notes.map((note) => note.y)) - slop
  const maxX = Math.max(...notes.map((note) => note.x + noteSize(note).width)) + slop
  const maxY = Math.max(...notes.map((note) => note.y + noteSize(note).height)) + slop

  const scale = window.devicePixelRatio > 1 ? 2 : 1
  const width = maxX - minX + PADDING * 2
  const height = maxY - minY + PADDING * 2

  const canvas = document.createElement('canvas')
  canvas.width = width * scale
  canvas.height = height * scale
  const ctx = canvas.getContext('2d')
  ctx.scale(scale, scale)

  ctx.fillStyle = BOARD_BG
  ctx.fillRect(0, 0, width, height)

  for (const note of notes) {
    drawNote(ctx, note, minX - PADDING, minY - PADDING)
  }

  download(canvas, filename)
  return true
}

export { NOTE_COLORS }
