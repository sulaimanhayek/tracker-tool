import { useEffect, useMemo, useRef, useState } from 'react'
import StickyNote from './StickyNote.jsx'
import { exportNotesToDoc } from './exportDoc'
import { exportNotesToPng } from './exportPng'
import {
  NOTES_STORAGE_KEY,
  NOTE_COLORS,
  NOTE_SIZE,
  STACK_GAP_X,
  STACK_PEEK,
  STACK_STEP_Y,
  noteSize,
  stampFilename
} from './notes'

const uid = () => Math.random().toString(36).slice(2, 10)

function initialState() {
  const board = { id: uid(), name: 'Board' }
  return { folders: [board], notes: [], activeFolderId: board.id, topZ: 1, layout: 'free' }
}

// Storage is local only for now; the user asked to settle real storage later.
function loadNotes() {
  try {
    const raw = localStorage.getItem(NOTES_STORAGE_KEY)
    if (!raw) return initialState()
    const saved = JSON.parse(raw)
    if (!saved?.folders?.length) return initialState()
    return {
      folders: saved.folders,
      notes: saved.notes ?? [],
      activeFolderId: saved.activeFolderId ?? saved.folders[0].id,
      topZ: saved.topZ ?? 1,
      layout: saved.layout === 'stacked' ? 'stacked' : 'free'
    }
  } catch {
    return initialState()
  }
}

export default function NotesPage({ active }) {
  const [state, setState] = useState(loadNotes)
  const { folders, notes, activeFolderId, topZ, layout } = state
  const boardRef = useRef(null)
  // null | 'new' | 'rename' — inline, so the page never depends on a blocking
  // window.prompt that some embedded browsers suppress.
  const [editing, setEditing] = useState(null)

  useEffect(() => {
    localStorage.setItem(NOTES_STORAGE_KEY, JSON.stringify(state))
  }, [state])

  const activeFolder = folders.find((folder) => folder.id === activeFolderId) ?? folders[0]
  const visible = useMemo(
    () => notes.filter((note) => note.folderId === activeFolder.id),
    [notes, activeFolder.id]
  )

  const addNote = () => {
    const bounds = boardRef.current?.getBoundingClientRect()
    const width = bounds?.width ?? 900
    const height = bounds?.height ?? 600
    const gap = 24
    const columns = Math.max(1, Math.floor((width - gap) / (NOTE_SIZE + gap)))
    const rows = Math.max(1, Math.floor((height - gap) / (NOTE_SIZE + gap)))
    const index = visible.length

    // Lay new notes out on a grid, then cascade once the grid is full so a note
    // is never dropped outside the board (which clips its overflow).
    let x = gap + (index % columns) * (NOTE_SIZE + gap)
    let y = gap + Math.floor(index / columns) * (NOTE_SIZE + gap)
    if (index >= columns * rows) {
      const step = ((index - columns * rows) % 12) * 26 + gap
      x = step
      y = step
    }

    const note = {
      id: uid(),
      folderId: activeFolder.id,
      text: '',
      color: NOTE_COLORS[index % NOTE_COLORS.length].key,
      createdAt: Date.now(),
      width: NOTE_SIZE,
      height: NOTE_SIZE,
      x: Math.max(0, Math.min(x, width - NOTE_SIZE)),
      y: Math.max(0, Math.min(y, height - NOTE_SIZE)),
      rotation: Math.round((Math.random() * 4 - 2) * 10) / 10,
      z: topZ + 1
    }
    setState((current) => ({ ...current, notes: [...current.notes, note], topZ: current.topZ + 1 }))
  }

  const changeNote = (id, patch) => {
    setState((current) => ({
      ...current,
      notes: current.notes.map((note) => (note.id === id ? { ...note, ...patch } : note))
    }))
  }

  const deleteNote = (id) => {
    setState((current) => ({ ...current, notes: current.notes.filter((note) => note.id !== id) }))
  }

  const liftNote = (id) => {
    setState((current) => {
      const note = current.notes.find((item) => item.id === id)
      if (!note || note.z === current.topZ) return current
      const z = current.topZ + 1
      return {
        ...current,
        topZ: z,
        notes: current.notes.map((item) => (item.id === id ? { ...item, z } : item))
      }
    })
  }

  // Lay the folder's notes out in columns, each one collapsed to its top bar
  // and first line; hovering a note brings the whole thing back.
  const organise = () => {
    const bounds = boardRef.current?.getBoundingClientRect()
    const height = bounds?.height ?? 600
    const perColumn = Math.max(1, Math.floor((height - STACK_GAP_X) / STACK_STEP_Y))
    const columnWidth =
      Math.max(NOTE_SIZE, ...visible.map((note) => noteSize(note).width)) + STACK_GAP_X

    const placed = new Map(
      visible.map((note, index) => [
        note.id,
        {
          x: STACK_GAP_X + Math.floor(index / perColumn) * columnWidth,
          y: STACK_GAP_X + (index % perColumn) * STACK_STEP_Y,
          rotation: 0,
          z: index + 1
        }
      ])
    )

    setState((current) => ({
      ...current,
      layout: 'stacked',
      topZ: Math.max(current.topZ, placed.size),
      notes: current.notes.map((note) =>
        placed.has(note.id) ? { ...note, ...placed.get(note.id) } : note
      )
    }))
  }

  const addFolder = (name) => {
    const trimmed = name.trim()
    if (!trimmed) return
    const folder = { id: uid(), name: trimmed }
    setState((current) => ({
      ...current,
      folders: [...current.folders, folder],
      activeFolderId: folder.id
    }))
  }

  const renameFolder = (name) => {
    const trimmed = name.trim()
    if (!trimmed) return
    setState((current) => ({
      ...current,
      folders: current.folders.map((folder) =>
        folder.id === activeFolder.id ? { ...folder, name: trimmed } : folder
      )
    }))
  }

  const removeFolder = () => {
    if (folders.length === 1) return
    const count = notes.filter((note) => note.folderId === activeFolder.id).length
    if (count > 0 && !window.confirm(`Delete "${activeFolder.name}" and its ${count} note(s)?`)) return
    setState((current) => {
      const remaining = current.folders.filter((folder) => folder.id !== activeFolder.id)
      return {
        ...current,
        folders: remaining,
        notes: current.notes.filter((note) => note.folderId !== activeFolder.id),
        activeFolderId: remaining[0].id
      }
    })
  }

  // Files are named after the timestamp: the note's creation time for a single
  // note, the moment of export for a whole board.
  const exportBoard = () => {
    exportNotesToPng(visible, `${stampFilename()}.png`, layout === 'stacked' ? STACK_PEEK : null)
  }

  const exportDoc = () => {
    exportNotesToDoc(visible, `${stampFilename()}.doc`, activeFolder.name)
  }

  const exportNote = (note) => {
    exportNotesToPng([{ ...note, x: 0, y: 0, rotation: 0 }], `${stampFilename(note.createdAt)}.png`)
  }

  return (
    <main className="main notes-main" hidden={!active}>
      <div className="notes-bar">
        <div className="folder-tabs" role="tablist" aria-label="Folders">
          {folders.map((folder) => (
            <button
              key={folder.id}
              role="tab"
              aria-selected={folder.id === activeFolder.id}
              className={folder.id === activeFolder.id ? 'folder-tab active' : 'folder-tab'}
              onClick={() => setState((current) => ({ ...current, activeFolderId: folder.id }))}
              onDoubleClick={() => folder.id === activeFolder.id && setEditing('rename')}
            >
              {folder.name}
              <span className="folder-count">
                {notes.filter((note) => note.folderId === folder.id).length}
              </span>
            </button>
          ))}
          <button className="folder-add" onClick={() => setEditing('new')} title="New folder">
            + Folder
          </button>
        </div>

        <div className="notes-actions">
          {folders.length > 1 && (
            <button className="ghost small" onClick={removeFolder}>
              Delete folder
            </button>
          )}
          <button className="ghost small" onClick={exportBoard} disabled={visible.length === 0}>
            Save as PNG
          </button>
          <button
            className="ghost small"
            onClick={exportDoc}
            disabled={visible.length === 0}
            title="Compile every note in this folder into one Word document"
          >
            Save as Word
          </button>
          <button
            className="ghost small"
            onClick={() => (layout === 'stacked' ? setState((c) => ({ ...c, layout: 'free' })) : organise())}
            disabled={visible.length === 0 && layout !== 'stacked'}
            title={
              layout === 'stacked'
                ? 'Show every note in full again'
                : 'Arrange the notes in columns, collapsed to their first line'
            }
          >
            {layout === 'stacked' ? 'Expand all' : 'Organise'}
          </button>
          <button className="primary small" onClick={addNote}>
            + New note
          </button>
        </div>
      </div>

      {editing && (
        <form
          className="folder-rename"
          onSubmit={(event) => {
            event.preventDefault()
            const name = new FormData(event.currentTarget).get('name')
            if (editing === 'new') addFolder(name)
            else renameFolder(name)
            setEditing(null)
          }}
        >
          <input
            key={editing}
            name="name"
            defaultValue={editing === 'rename' ? activeFolder.name : ''}
            placeholder="Folder name"
            autoFocus
            aria-label="Folder name"
            onKeyDown={(event) => event.key === 'Escape' && setEditing(null)}
          />
          <button type="submit">{editing === 'new' ? 'Create' : 'Rename'}</button>
          <button type="button" onClick={() => setEditing(null)}>
            Cancel
          </button>
        </form>
      )}

      <div className="board" ref={boardRef}>
        {visible.length === 0 && (
          <p className="board-empty">
            Nothing pinned to “{activeFolder.name}” yet — add a note and drag it anywhere.
          </p>
        )}
        {visible.map((note) => (
          <StickyNote
            key={note.id}
            note={note}
            folders={folders}
            onChange={changeNote}
            onDelete={deleteNote}
            onLift={liftNote}
            onExport={exportNote}
            stacked={layout === 'stacked'}
          />
        ))}
      </div>

      <p className="notes-hint">
        {layout === 'stacked'
          ? 'Hover a note to read it in full. “Expand all” goes back to the open board.'
          : 'Drag a note by its top bar and resize it from the bottom-right corner — or focus either and use the arrow keys.'}{' '}
        Notes are kept in this browser for now.
      </p>
    </main>
  )
}
