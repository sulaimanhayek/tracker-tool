import { useRef } from 'react'
import {
  MIN_NOTE_HEIGHT,
  MIN_NOTE_WIDTH,
  NOTE_COLORS,
  colorValue,
  formatStamp,
  formatStampLong,
  noteSize
} from './notes'

export default function StickyNote({ note, folders, stacked, onChange, onDelete, onLift, onExport }) {
  const drag = useRef(null)
  const resize = useRef(null)
  const { width, height } = noteSize(note)

  const startDrag = (event) => {
    if (event.button !== 0) return
    onLift(note.id)
    const board = event.currentTarget.closest('.board')
    const bounds = board.getBoundingClientRect()
    drag.current = {
      offsetX: event.clientX - bounds.left - note.x,
      offsetY: event.clientY - bounds.top - note.y,
      maxX: Math.max(0, bounds.width - width),
      maxY: Math.max(0, bounds.height - height)
    }
    event.currentTarget.setPointerCapture(event.pointerId)
    event.preventDefault()
  }

  const moveDrag = (event) => {
    const state = drag.current
    if (!state) return
    const board = event.currentTarget.closest('.board').getBoundingClientRect()
    onChange(note.id, {
      x: Math.max(0, Math.min(state.maxX, event.clientX - board.left - state.offsetX)),
      y: Math.max(0, Math.min(state.maxY, event.clientY - board.top - state.offsetY))
    })
  }

  const endDrag = (event) => {
    if (!drag.current) return
    drag.current = null
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId)
    }
  }

  const startResize = (event) => {
    if (event.button !== 0) return
    onLift(note.id)
    const bounds = event.currentTarget.closest('.board').getBoundingClientRect()
    resize.current = {
      startX: event.clientX,
      startY: event.clientY,
      width,
      height,
      maxWidth: bounds.width - note.x,
      maxHeight: bounds.height - note.y
    }
    event.currentTarget.setPointerCapture(event.pointerId)
    event.preventDefault()
    event.stopPropagation()
  }

  const moveResize = (event) => {
    const state = resize.current
    if (!state) return
    onChange(note.id, {
      width: Math.round(
        Math.max(
          MIN_NOTE_WIDTH,
          Math.min(state.maxWidth, state.width + event.clientX - state.startX)
        )
      ),
      height: Math.round(
        Math.max(
          MIN_NOTE_HEIGHT,
          Math.min(state.maxHeight, state.height + event.clientY - state.startY)
        )
      )
    })
  }

  const endResize = (event) => {
    if (!resize.current) return
    resize.current = null
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId)
    }
  }

  // Arrow keys resize the note when Alt is held, otherwise they move it.
  const resizeByKey = (event) => {
    const step = event.shiftKey ? 40 : 8
    const deltas = {
      ArrowUp: [0, -step],
      ArrowDown: [0, step],
      ArrowLeft: [-step, 0],
      ArrowRight: [step, 0]
    }
    const delta = deltas[event.key]
    if (!delta) return false
    event.preventDefault()
    onChange(note.id, {
      width: Math.max(MIN_NOTE_WIDTH, width + delta[0]),
      height: Math.max(MIN_NOTE_HEIGHT, height + delta[1])
    })
    return true
  }

  // Arrow keys move the note for anyone who cannot drag with a pointer.
  const nudge = (event) => {
    if (event.altKey) {
      resizeByKey(event)
      return
    }
    const step = event.shiftKey ? 40 : 8
    const deltas = {
      ArrowUp: [0, -step],
      ArrowDown: [0, step],
      ArrowLeft: [-step, 0],
      ArrowRight: [step, 0]
    }
    const delta = deltas[event.key]
    if (!delta) return
    event.preventDefault()
    onLift(note.id)
    onChange(note.id, { x: Math.max(0, note.x + delta[0]), y: Math.max(0, note.y + delta[1]) })
  }

  return (
    <article
      className={stacked ? 'note stacked' : 'note'}
      style={{
        '--note-color': colorValue(note.color),
        '--note-width': `${width}px`,
        '--note-height': `${height}px`,
        transform: `translate(${note.x}px, ${note.y}px) rotate(${note.rotation}deg)`,
        zIndex: note.z
      }}
      onPointerDown={() => onLift(note.id)}
    >
      <div
        className="note-grip"
        onPointerDown={startDrag}
        onPointerMove={moveDrag}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onKeyDown={nudge}
        tabIndex={0}
        role="button"
        aria-label={`Move note${note.text ? `: ${note.text.slice(0, 40)}` : ''}`}
        title="Drag to move"
      >
        <span className="note-grip-dots" aria-hidden="true" />
        {note.createdAt && (
          <time
            className="note-stamp"
            dateTime={new Date(note.createdAt).toISOString()}
            title={`Created ${formatStampLong(note.createdAt)}`}
          >
            {formatStamp(note.createdAt)}
          </time>
        )}
        <button
          className="note-close"
          onClick={() => onDelete(note.id)}
          aria-label="Delete note"
          title="Delete note"
        >
          ×
        </button>
      </div>

      <textarea
        className="note-text"
        value={note.text}
        placeholder="Write something…"
        onChange={(event) => onChange(note.id, { text: event.target.value })}
        aria-label="Note text"
      />

      <div className="note-footer">
        <div className="note-colors" role="group" aria-label="Note colour">
          {NOTE_COLORS.map((color) => (
            <button
              key={color.key}
              className={color.key === note.color ? 'swatch active' : 'swatch'}
              style={{ background: color.value }}
              onClick={() => onChange(note.id, { color: color.key })}
              aria-label={color.label}
              aria-pressed={color.key === note.color}
              title={color.label}
            />
          ))}
        </div>

        <div className="note-actions">
          {folders.length > 1 && (
            <select
              className="note-folder"
              value={note.folderId}
              onChange={(event) => onChange(note.id, { folderId: event.target.value })}
              aria-label="Move to folder"
              title="Move to folder"
            >
              {folders.map((folder) => (
                <option key={folder.id} value={folder.id}>
                  {folder.name}
                </option>
              ))}
            </select>
          )}
          <button
            className="note-png"
            onClick={() => onExport(note)}
            aria-label="Save note as PNG"
            title="Save as PNG"
          >
            PNG
          </button>
        </div>
      </div>

      <div
        className="note-resize"
        onPointerDown={startResize}
        onPointerMove={moveResize}
        onPointerUp={endResize}
        onPointerCancel={endResize}
        onKeyDown={(event) => resizeByKey(event)}
        tabIndex={0}
        role="button"
        aria-label={`Resize note (${width} by ${height})`}
        title="Drag to resize"
      >
        <span aria-hidden="true" />
      </div>
    </article>
  )
}
