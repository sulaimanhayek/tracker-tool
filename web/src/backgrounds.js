// Background themes. Each one sets the whole token set, so a light background
// still reads: the app never assumes a dark canvas.
export const BACKGROUNDS = [
  {
    key: 'midnight',
    label: 'Midnight',
    scheme: 'dark',
    vars: {
      '--bg': '#12141a',
      '--surface': '#1a1d26',
      '--border': '#272b38',
      '--text': '#e8eaf0',
      '--muted': '#8b90a3',
      '--track': '#3a3f4d'
    }
  },
  {
    key: 'ink',
    label: 'Ink',
    scheme: 'dark',
    vars: {
      '--bg': '#07080b',
      '--surface': '#111318',
      '--border': '#1f2229',
      '--text': '#e6e8ee',
      '--muted': '#808493',
      '--track': '#2f333d'
    }
  },
  {
    key: 'slate',
    label: 'Slate',
    scheme: 'dark',
    vars: {
      '--bg': '#1b2029',
      '--surface': '#242a35',
      '--border': '#333b49',
      '--text': '#e9edf4',
      '--muted': '#929aac',
      '--track': '#454d5e'
    }
  },
  {
    key: 'forest',
    label: 'Forest',
    scheme: 'dark',
    vars: {
      '--bg': '#0f1a15',
      '--surface': '#17241e',
      '--border': '#24352c',
      '--text': '#e6f0e9',
      '--muted': '#879a90',
      '--track': '#33483d'
    }
  },
  {
    key: 'paper',
    label: 'Paper',
    scheme: 'light',
    vars: {
      '--bg': '#f2f3f7',
      '--surface': '#ffffff',
      '--border': '#dcdfe8',
      '--text': '#1d2028',
      '--muted': '#666c7d',
      '--track': '#c9cdd9'
    }
  },
  {
    key: 'parchment',
    label: 'Parchment',
    scheme: 'light',
    vars: {
      '--bg': '#f5f0e4',
      '--surface': '#fffcf3',
      '--border': '#e3dac5',
      '--text': '#2b2618',
      '--muted': '#6f6853',
      '--track': '#d3c8ac'
    }
  }
]

export const BACKGROUND_STORAGE_KEY = 'tracker-tool.background.v1'

export function backgroundByKey(key) {
  return BACKGROUNDS.find((background) => background.key === key) ?? BACKGROUNDS[0]
}
