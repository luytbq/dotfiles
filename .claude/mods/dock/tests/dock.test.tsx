import { expect, mock, test } from 'claude-code/testing'
import type { On, SessionRateLimit, SessionUsage } from 'claude-code'

const NOW = Date.parse('2026-10-04T06:00:00Z')
const MIN = 60_000
const HOUR = 60 * MIN

const PROPS = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 20,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 20 },
  view: {},
}
const BAND = { plugin: 'dock', surface: 'terminal', component: 'AbovePrompt', props: PROPS } as const

const CATEGORIES = [
  { name: 'System prompt', tokens: 4_000, kind: 'used' },
  { name: 'System tools', tokens: 34_000, kind: 'used' },
  { name: 'MCP tools', tokens: 17_000, kind: 'used' },
  { name: 'Messages', tokens: 97_000, kind: 'used' },
  { name: 'Autocompact buffer', tokens: 33_000, kind: 'buffer' },
  { name: 'Free space', tokens: 815_000, kind: 'free' },
].map(c => ({ color: 'text', isDeferred: false, ...c }))

function usage(rateLimits: SessionRateLimit[], percent: number): SessionUsage {
  return {
    startedAt: NOW - HOUR,
    context: {
      window: 1_000_000,
      tokens: percent * 10_000,
      percent,
      breakdown: { categories: CATEGORIES, totalTokens: 152_000, maxTokens: 1_000_000, rawMaxTokens: 1_000_000, percentage: percent } as never,
    },
    rateLimits,
  }
}

const iso = (ms: number) => new Date(NOW + ms).toISOString()

// what the engine answers beneath the plugin
function world(on: On, rateLimits: SessionRateLimit[] = [], percent = 16, stored?: Record<string, unknown>) {
  const now = { rateLimits, percent }
  mock.clock(on, { now: NOW })
  if (stored) {
    on('store.get', (_, e) => ({ value: stored[e.key] }))
    on('store.set', (_, e) => {
      stored[e.key] = e.value
      return { value: undefined }
    })
  } else mock.store(on)
  on('session.usage', () => ({ value: usage(now.rateLimits, now.percent) }))
  on('session.authorize', () => ({ value: null }))
  on('session.measure', () => ({ changed: [] }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'dock' } }))
  on('ui.render', () => ({ type: 'Box', props: {}, children: [] }) as never)
  on('ui.status', () => ({ value: undefined }))
  on('tool.call', () => ({ result: {} }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('prompt.compose', () => ({ sections: [] }))
  on('turn.complete', () => ({ text: '' }))
  return now
}

const COMPOSE = {
  model: 'claude-opus-5-5',
  promptModel: 'claude-opus-5-5',
  surfaces: ['terminal'],
  tools: [],
  outputStyle: null,
  traits: [],
  sections: [],
} as const

const START = { cwd: '/', surface: 'terminal', isInteractive: true } as const

test('the tab bar shows both tabs with their summaries', async ($, on) => {
  world(on, [
    { kind: 'five_hour', percentUsed: 42, resetsAt: iso(HOUR + 3 * MIN) },
    { kind: 'seven_day', percentUsed: 18, resetsAt: iso(4 * 24 * HOUR + 2 * HOUR) },
  ])
  await $.session.start(START)
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ key: 'dock-tab-usage' })).toBeDefined()
  expect(await ui.find({ key: 'dock-tab-limit' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: ' 42·18·16% ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: ' L- T- ' })).toBeDefined()
  // all well on both tabs: no attention icon at all
  expect(await ui.find({ type: 'Text', text: /[✔▲✖]/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'resets in 1h 3m' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'resets in 4d 2h' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Messages 105k' })).toBeDefined()
  // Messages is the reply's input total less Tools (34k + 17k) and Other (4k)
  expect(await ui.find({ type: 'Text', text: 'Tools 51k' })).toBeDefined()
  await ui.unmount()
})

test('pressing a tab switches the content, and the arrows cycle', async ($, on) => {
  world(on)
  await $.session.start(START)
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'dock-tab-limit' })
  expect(await ui.find({ type: 'Text', text: 'Lines' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Context' })).toBeUndefined()
  await ui.press({ key: 'dock-next' })
  expect(await ui.find({ type: 'Text', text: 'Context' })).toBeDefined()
  await ui.press({ key: 'dock-prev' })
  expect(await ui.find({ type: 'Text', text: 'Lines' })).toBeDefined()
  await ui.unmount()
})

test('Usage needs attention from 75% of a limit, and alerts from 80% of the context', async ($, on) => {
  const usageNow = world(on, [{ kind: 'five_hour', percentUsed: 80, resetsAt: iso(HOUR) }], 30)
  await $.session.start(START)
  let ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: '▲ ' })).toBeDefined()
  await ui.unmount()

  usageNow.rateLimits = [{ kind: 'five_hour', percentUsed: 10, resetsAt: iso(HOUR) }]
  usageNow.percent = 85
  await $.session.measure({ context: { window: 1_000_000, tokens: 850_000, percent: 85 }, rateLimits: [], changed: [] } as never)
  ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: '✖ ' })).toBeDefined()
  await ui.unmount()
})

test('the stepper turns a limit on, the switch turns it off, and the tool budget denies past it', async ($, on) => {
  world(on)
  await $.session.start(START)
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'dock-tab-limit' })
  await ui.press({ key: 'tools-dec' })
  await ui.press({ key: 'tools-dec' })
  expect(await ui.find({ type: 'Text', text: ' L- T1 ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '▲ ' })).toBeDefined()

  await $.prompt.submit({ text: 'go' } as never)
  const first = await $.tool.call({ tool: 'Bash', command: 'ls' } as never)
  expect((first as { deny?: string }).deny).toBeUndefined()
  const second = await $.tool.call({ tool: 'Bash', command: 'ls' } as never)
  expect((second as { deny?: string }).deny).toMatch(/tool budget of 1/)

  const composed = await $.prompt.compose(COMPOSE)
  expect(composed.sections.some(s => s.id === 'dock:limits')).toBe(true)

  await $.turn.complete({ answer: 'done' } as never)
  expect(await ui.find({ type: 'Text', text: '✖ ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'last turn · 1 lines · 1 tools' })).toBeDefined()

  await ui.press({ key: 'tools-toggle' })
  expect(await ui.find({ type: 'Text', text: ' L- T- ' })).toBeDefined()
  const off = await $.prompt.compose(COMPOSE)
  expect(off.sections.some(s => s.id === 'dock:limits')).toBe(false)
  await ui.unmount()
})

test('/dock hides the band and keeps what the plugins beneath draw', async ($, on) => {
  world(on)
  await $.session.start(START)
  const result = await $.command.run({ command: 'dock', args: '' } as never)
  expect((result as { text?: string }).text).toBe('Dock hidden.')
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ key: 'dock-tab-usage' })).toBeUndefined()
  await ui.unmount()
})

test('caps start off in a new session, their values kept', async ($, on) => {
  world(on, [], 16, { limits: { lines: { value: 5, isOn: true }, tools: { value: 2, isOn: true } } })
  await $.session.start(START)
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: ' L- T- ' })).toBeDefined()
  await ui.press({ key: 'dock-tab-limit' })
  await ui.press({ key: 'lines-toggle' })
  expect(await ui.find({ type: 'Text', text: ' L5 T- ' })).toBeDefined()
  await ui.unmount()
})
