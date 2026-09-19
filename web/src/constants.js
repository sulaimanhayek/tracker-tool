export const MODES = {
  focus: { key: 'focus', label: 'Focus', defaultMinutes: 60 },
  short: { key: 'short', label: 'Short Break', defaultMinutes: 5 },
  long: { key: 'long', label: 'Long Break', defaultMinutes: 15 }
}

export const MODE_ORDER = ['focus', 'short', 'long']

export const DEFAULT_DURATIONS = {
  focus: MODES.focus.defaultMinutes,
  short: MODES.short.defaultMinutes,
  long: MODES.long.defaultMinutes
}

// Focus rounds completed before a long break is suggested.
export const ROUNDS_BEFORE_LONG_BREAK = 4

export const STORAGE_KEY = 'tracker-tool.state.v1'
