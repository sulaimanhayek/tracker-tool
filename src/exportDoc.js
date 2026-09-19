import { formatStampLong } from './notes'

function escapeHtml(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function noteSection(note) {
  const lines = (note.text ?? '').split('\n')
  const title = lines[0]?.trim() || 'Untitled note'
  const body = lines
    .slice(1)
    .map((line) => (line.trim() === '' ? '<p>&nbsp;</p>' : `<p>${escapeHtml(line)}</p>`))
    .join('\n')

  return `
    <h2>${escapeHtml(title)}</h2>
    <p class="stamp">${escapeHtml(formatStampLong(note.createdAt) || 'No timestamp')}</p>
    ${body}
  `
}

// Word opens HTML with a .doc extension as a document, which keeps the export
// dependency-free — a real .docx would need a zip writer.
export function exportNotesToDoc(notes, filename, heading) {
  if (notes.length === 0) return false

  const ordered = [...notes].sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0))

  const html = `<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head>
  <meta charset="utf-8">
  <title>${escapeHtml(heading)}</title>
  <style>
    body { font-family: Calibri, Arial, sans-serif; font-size: 11pt; }
    h1 { font-size: 18pt; }
    h2 { font-size: 14pt; margin-bottom: 2pt; }
    p.stamp { color: #666666; font-size: 9pt; margin-top: 0; }
    hr { border: 0; border-top: 1px solid #999999; margin: 18pt 0; }
  </style>
</head>
<body>
  <h1>${escapeHtml(heading)}</h1>
  ${ordered.map(noteSection).join('\n<hr>\n')}
</body>
</html>`

  const blob = new Blob(['﻿', html], { type: 'application/msword' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  setTimeout(() => URL.revokeObjectURL(url), 10000)
  return true
}
