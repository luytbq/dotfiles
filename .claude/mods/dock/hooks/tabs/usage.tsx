import { atom, read, update } from 'claude-code'
import type { ElementTable, EngineInterface, RenderNode, SessionRateLimit } from 'claude-code'

import type { Category, PlanLimit, Snapshot } from '../../types'
import type { Attention, TabInfo, TabRequest } from '../tab'
import { AMBER, Bar, GREEN, MUTED, RED, TRACK } from '../widgets'

const snapshot = atom({ plugin: 'dock', key: 'snapshot' } as const, null as Snapshot | null)

const HOUR = 3_600_000
const WINDOWS: Record<string, { label: string; ms: number }> = {
  five_hour: { label: '5H', ms: 5 * HOUR },
  seven_day: { label: 'Weekly', ms: 7 * 24 * HOUR },
}
// a reset time read twice may drift by seconds: within this it is the same window
const SAME_WINDOW_MS = 10 * 60_000

const LIMIT_AMBER_AT = 75
const LIMIT_RED_AT = 90
const CONTEXT_AMBER_AT = 50
const CONTEXT_RED_AT = 80

const MESSAGES = '#22d3ee'
const TOOLS = '#a78bfa'
// Other and the autocompact buffer share one grey: both are room the chat cannot use
const OTHER = '#4b5163'

function levelOf(percent: number, amberAt: number, redAt: number): Attention {
  const shown = Math.round(percent)
  return shown >= redAt ? 'alert' : shown >= amberAt ? 'warn' : 'none'
}
const COLOR: Record<Attention, string> = { none: GREEN, warn: AMBER, alert: RED }

function duration(ms: number): string {
  const m = Math.max(0, Math.round(ms / 60_000))
  const d = Math.floor(m / 1440)
  const hours = Math.floor((m % 1440) / 60)
  const min = m % 60
  if (d > 0) return hours > 0 ? `${d}d ${hours}h` : `${d}d`
  if (hours > 0) return min > 0 ? `${hours}h ${min}m` : `${hours}h`
  return `${min}m`
}

function tokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`
  if (n >= 1000) return `${Math.round(n / 1000)}k`
  return `${Math.round(n)}`
}

// The usage service rate-limits per login, and the app's own Usage panel asks it on
// the same allowance, so ask it seldom: when a chat opens, then every 2 minutes, one
// ask for the whole app (when it was last asked, the answer and any back-off sit in
// the shared store). Between asks the figures every reply carries keep it current.
const PLAN_EVERY_MS = 2 * 60_000
// timers drift: a 2-minute tick a moment early still counts as due
const PLAN_SLACK_MS = 10_000
// after a failed ask wait 2, then 5, then 15 minutes, or what the service says
const PLAN_BACKOFF_MS = [120_000, 300_000, 900_000]
const LOCAL_EVERY_MS = 3_000

type Backoff = { until: number; failures: number; error: string }
/** 'no': the 3s tick, never asks; 'due': asks if 2 minutes have passed app-wide; 'now': asks unless backed off */
type Ask = 'no' | 'due' | 'now'

class AskError extends Error {
  constructor(
    message: string,
    readonly retryAfterMs?: number,
  ) {
    super(message)
  }
}

// The plan's limits as the app's "Plan usage limits" panel reads them, through the
// session's own credential (the plugin never sees it).
async function fetchPlan($: EngineInterface): Promise<PlanLimit[] | null> {
  const auth = await $.session.authorize()
  // no Claude login (an API key, a gateway): there is no plan to ask about
  if (!auth || auth.kind !== 'bearer') return null
  const res = await $.http.fetch('https://api.anthropic.com/api/oauth/usage', {
    auth: auth.handle,
    headers: { 'anthropic-beta': 'oauth-2025-04-20', 'content-type': 'application/json' },
  })
  if (!res.ok) {
    const header = Object.entries(res.headers ?? {}).find(([k]) => k.toLowerCase() === 'retry-after')?.[1]
    const seconds = Number(Array.isArray(header) ? header[0] : header)
    const retry = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : undefined
    throw new AskError(res.status === 429 ? 'refused (429)' : `failed (${res.status})`, retry)
  }
  const body = JSON.parse(res.text) as Record<string, { utilization?: number | null; resets_at?: string | null } | null>
  const limits: PlanLimit[] = []
  for (const kind of Object.keys(WINDOWS)) {
    const w = body[kind]
    if (!w || typeof w.utilization !== 'number') continue
    limits.push({ kind, percentUsed: Math.round(w.utilization * 10) / 10, resetsAt: w.resets_at ?? undefined })
  }
  if (limits.length === 0) throw new AskError('answer had no limits')
  return limits
}

type Saved = { at: number; limits: PlanLimit[] }

// this chat's own reading from its replies, and when it last changed
let live: Saved | undefined

async function storeGet($: EngineInterface, key: string): Promise<unknown> {
  try {
    return await $.store.get(key)
  } catch {
    return undefined
  }
}

async function storeSet($: EngineInterface, key: string, value: unknown): Promise<void> {
  try {
    await $.store.set(key, value)
  } catch {
    // this chat still has it
  }
}

const sameWindow = (a: string | undefined, b: string | undefined) =>
  a !== undefined && b !== undefined && Math.abs(Date.parse(a) - Date.parse(b)) <= SAME_WINDOW_MS

// Two sources, and the newest wins: the usage service (asked seldom, shared by every
// chat through the store) and the figures each reply carries (this chat's, stamped
// when they last changed). A window that has reset since is dropped.
async function limitsOf(
  $: EngineInterface,
  rateLimits: SessionRateLimit[],
  now: number,
  ask: Ask,
): Promise<{ limits: PlanLimit[]; at?: number; error?: string }> {
  if (rateLimits.length > 0) {
    const limits = rateLimits.map(r => ({ kind: r.kind, percentUsed: r.percentUsed, resetsAt: r.resetsAt }))
    if (!live || JSON.stringify(live.limits) !== JSON.stringify(limits)) live = { at: now, limits }
  }
  let saved = (await storeGet($, 'planSaved')) as Saved | undefined
  let backoff = (await storeGet($, 'planBackoff')) as Backoff | undefined
  const askedAt = ((await storeGet($, 'planAskedAt')) as number | undefined) ?? 0
  const isFree = now >= (backoff?.until ?? 0)
  const isDue = ask === 'now' || (ask === 'due' && now - askedAt >= PLAN_EVERY_MS - PLAN_SLACK_MS)
  if (isDue && isFree) {
    // claim the ask first, so the other chats see it taken and skip theirs
    await storeSet($, 'planAskedAt', now)
    try {
      const plan = await fetchPlan($)
      if (plan) {
        saved = { at: now, limits: plan }
        await storeSet($, 'planSaved', saved)
        await storeSet($, 'planLimits', saved)
      }
      if (backoff) await storeSet($, 'planBackoff', { until: 0, failures: 0, error: '' })
      backoff = undefined
    } catch (error) {
      const failures = (backoff?.failures ?? 0) + 1
      const wait =
        error instanceof AskError && error.retryAfterMs !== undefined
          ? error.retryAfterMs
          : PLAN_BACKOFF_MS[Math.min(failures - 1, PLAN_BACKOFF_MS.length - 1)]!
      backoff = { until: now + wait, failures, error: error instanceof Error ? error.message : String(error) }
      await storeSet($, 'planBackoff', backoff)
    }
  }
  const pick = [saved, live].filter((r): r is Saved => r !== undefined).sort((x, y) => y.at - x.at)[0]
  // newer reply figures go to the store too, so other chats get them
  if (pick && pick === live && (!saved || live.at > saved.at)) await storeSet($, 'planSaved', live)
  // The reply figures run behind the usage service: whole percents, seen at 18 for an
  // hour while the service said 19.0. Use only climbs within a window, so a reply
  // figure below the service's last answer is stale and the higher one is kept.
  const plan = (await storeGet($, 'planLimits')) as Saved | undefined
  const finer = (l: PlanLimit): PlanLimit => {
    const p = plan?.limits.find(x => x.kind === l.kind)
    return p && sameWindow(p.resetsAt, l.resetsAt) && p.percentUsed > l.percentUsed ? { ...l, percentUsed: p.percentUsed } : l
  }
  // a window that has reset since stays, at 0: drawn as not running
  const limits = (pick?.limits ?? []).map(l =>
    l.resetsAt !== undefined && Date.parse(l.resetsAt) <= now ? { kind: l.kind, percentUsed: 0 } : finer(l),
  )
  return { limits, at: pick?.at, error: backoff?.error || undefined }
}

// Context in three groups: Messages, Tools (System + MCP tools) and Other (the system
// prompt, skills, memory files, agents, MCP server instructions).
const TOOL_NAMES = new Set(['System tools', 'MCP tools'])
type Group = 'Messages' | 'Tools' | 'Other'
const groupOf = (name: string): Group => (name === 'Messages' ? 'Messages' : TOOL_NAMES.has(name) ? 'Tools' : 'Other')

function sumGroups(categories: readonly { name: string; tokens: number; kind: string }[]): Record<Group, number> {
  const sums: Record<Group, number> = { Messages: 0, Tools: 0, Other: 0 }
  for (const c of categories) if (c.kind === 'used') sums[groupOf(c.name)] += c.tokens
  return sums
}

// The free local breakdown ('summary') estimates each category from its text, which
// reads tools ~1.3-1.6x heavy. The exact count ('full', what /context shows) costs no
// tokens but sends one token-count request per tool and memory file, so it runs every
// 2 minutes and its exact/estimate ratio of Tools and Other scales the 3s estimate.
const CALIBRATE_EVERY_MS = 2 * 60_000
let calib: Partial<Record<Group, number>> = {}
let isCalibrating = false
// Right after /compact there is no API reply yet, so the window's real total is unknown;
// the exact count fills that gap until the next reply.
let exactCount: { at: number; sums: Record<Group, number> } | undefined
let noReplySince: number | undefined

let isRefreshing = false
// an ask that came while a refresh ran: done right after it
let pendingAsk: Ask = 'no'
let lastSnapshot = ''
let hadError = false

async function calibrate($: EngineInterface): Promise<void> {
  if (isCalibrating) return
  isCalibrating = true
  try {
    const exact = await $.session.usage({ breakdown: 'full' })
    const rough = await $.session.usage({ breakdown: 'summary' })
    const real = sumGroups(exact.context.breakdown?.categories ?? [])
    const guess = sumGroups(rough.context.breakdown?.categories ?? [])
    const next = { ...calib }
    for (const g of ['Tools', 'Other'] as const) if (guess[g] > 0 && real[g] > 0) next[g] = real[g] / guess[g]
    calib = next
    exactCount = { at: await $.clock.now(), sums: real }
    await storeSet($, 'calib', next)
    lastSnapshot = ''
  } catch (error) {
    $.ui.log(`dock: exact count failed: ${error instanceof Error ? error.message : String(error)}`, { to: 'debug' })
  } finally {
    isCalibrating = false
  }
  // the usage service is asked alongside, on the same 2 minutes
  await refresh($, 'due')
}

async function refresh($: EngineInterface, ask: Ask = 'no'): Promise<void> {
  if (isRefreshing) {
    if (ask === 'now' || (ask === 'due' && pendingAsk === 'no')) pendingAsk = ask
    return
  }
  isRefreshing = true
  try {
    const now = await $.clock.now()
    const usage = await $.session.usage({ breakdown: 'summary' })
    const { context } = usage
    const breakdown = context.breakdown
    const all = (breakdown?.categories ?? []).filter(c => c.kind !== 'deferred' && c.tokens > 0)
    const rough = sumGroups(all)
    if (context.tokens === undefined) {
      // no reply since the chat opened or was compacted: get the exact count once
      if (noReplySince === undefined) {
        noReplySince = now
        $.clock.after(0, () => void calibrate($))
      }
    } else noReplySince = undefined
    const useExact = context.tokens === undefined && exactCount !== undefined && noReplySince !== undefined && exactCount.at >= noReplySince
    let tools = Math.round(rough.Tools * (calib.Tools ?? 1))
    let other = Math.round(rough.Other * (calib.Other ?? 1))
    // Messages is what the window holds beyond everything else, as /context counts it:
    // the API's real input total less the other groups, not the local estimate
    let messages = context.tokens !== undefined && context.tokens - tools - other > 0 ? context.tokens - tools - other : rough.Messages
    if (useExact) ({ Messages: messages, Tools: tools, Other: other } = exactCount!.sums)
    const used = context.tokens ?? (useExact ? messages + tools + other : (breakdown?.totalTokens ?? 0))
    const categories: Category[] = [
      { name: 'Messages', tokens: messages, kind: 'used' as const },
      { name: 'Tools', tokens: tools, kind: 'used' as const },
      { name: 'Other', tokens: other, kind: 'used' as const },
      ...all
        .filter(c => c.kind === 'buffer' || c.kind === 'free')
        .map(c => ({ name: c.name, tokens: c.tokens, kind: c.kind as Category['kind'] })),
    ].filter(c => c.tokens > 0)
    const { limits, at: limitsAt, error: limitsError } = await limitsOf($, usage.rateLimits, now, ask)
    const next: Snapshot = {
      window: context.window,
      tokens: used,
      percent: useExact
        ? Math.round((used / context.window) * 100)
        : (context.percent ?? breakdown?.percentage ?? Math.round((used / context.window) * 100)),
      categories,
      limits,
      ...(limitsAt !== undefined ? { limitsAt } : {}),
      ...(limitsError ? { limitsError } : {}),
      // the minute, so countdowns redraw even when nothing else moves
      minute: Math.floor(now / 60_000),
    }
    // redraw only when something moved, not on every tick
    const json = JSON.stringify(next)
    if (json !== lastSnapshot) {
      lastSnapshot = json
      await update($, snapshot, () => next)
    }
    if (hadError) $.ui.status(undefined)
    hadError = false
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    $.ui.status(`dock: ${message.replace(/^dock: /, '')}`)
    hadError = true
  } finally {
    isRefreshing = false
  }
  if (pendingAsk !== 'no') {
    const queued = pendingAsk
    pendingAsk = 'no'
    await refresh($, queued)
  }
}

/** both windows once there is any reading: one the reading lacks is not running */
function windowsOf(snap: Snapshot): PlanLimit[] {
  if (snap.limits.length === 0) return []
  return Object.keys(WINDOWS).map(kind => snap.limits.find(l => l.kind === kind) ?? { kind, percentUsed: 0 })
}

function attentionOf(snap: Snapshot): Attention {
  const levels = [
    ...windowsOf(snap).map(l => levelOf(l.percentUsed, LIMIT_AMBER_AT, LIMIT_RED_AT)),
    levelOf(snap.percent, CONTEXT_AMBER_AT, CONTEXT_RED_AT),
  ]
  return levels.includes('alert') ? 'alert' : levels.includes('warn') ? 'warn' : 'none'
}

export const USAGE: TabInfo = { id: 'usage', title: 'Usage' }

export async function usageTab($: EngineInterface, req: TabRequest): Promise<unknown> {
  switch (req.kind) {
    case 'sessionStart':
      calib = ((await storeGet($, 'calib')) as typeof calib | undefined) ?? {}
      // a chat just opened: its limits now, unless another chat asked a moment ago
      await refresh($, 'due')
      // the exact count on a timer, never from the hook itself: work a hook starts and
      // leaves running ends with its dispatch
      $.clock.after(2_000, () => void calibrate($))
      $.clock.every(CALIBRATE_EVERY_MS, () => void calibrate($))
      $.clock.every(LOCAL_EVERY_MS, () => void refresh($))
      return
    case 'sessionMeasure':
    case 'turnComplete':
      await refresh($)
      return
    case 'summary': {
      const snap = await read($, snapshot)
      if (!snap) return '…'
      const parts = [...windowsOf(snap).map(l => l.percentUsed), snap.percent].map(p => String(Math.round(p)))
      return `${parts.join('·')}%`
    }
    case 'attention': {
      const snap = await read($, snapshot)
      return snap ? attentionOf(snap) : 'none'
    }
    case 'render':
      return render($, req.ui, req.width)
    default:
      return undefined
  }
}

async function render($: EngineInterface, ui: ElementTable, width: number): Promise<RenderNode> {
  const { Box, Text } = ui
  const snap = await read($, snapshot)
  if (!snap) return <Text color={MUTED}>Reading usage…</Text>
  const now = await $.clock.now()
  const LABEL = 8
  // label, bar, then "100%" and two gaps; the rest of the row is the note
  const cells = Math.max(8, Math.min(24, width - LABEL - 6 - 32))

  const age = snap.limitsAt === undefined ? 0 : now - snap.limitsAt
  const windows = windowsOf(snap)
  const stale =
    snap.limitsError && age >= 2 * 60_000 && windows.length > 0
      ? `usage check ${snap.limitsError} – figures from ${duration(age)} ago`
      : snap.limitsError && windows.length === 0
        ? `usage check ${snap.limitsError}`
        : undefined

  const pct = (p: number, color: string) => (
    <Box width={6} flexShrink={0} justifyContent="flex-end">
      <Text bold color={color}>{`${Math.round(p)}%`}</Text>
    </Box>
  )

  const limitRows = windows.map(l => {
    const color = COLOR[levelOf(l.percentUsed, LIMIT_AMBER_AT, LIMIT_RED_AT)]
    const resetsAt = l.resetsAt === undefined ? NaN : Date.parse(l.resetsAt)
    const note = Number.isFinite(resetsAt) && l.percentUsed > 0 ? `resets in ${duration(resetsAt - now)}` : 'starts with your next message'
    return (
      <Box key={l.kind} flexDirection="row">
        <Box width={LABEL} flexShrink={0}>
          <Text bold>{WINDOWS[l.kind]?.label ?? l.kind}</Text>
        </Box>
        <Bar ui={ui} cells={cells} segments={[{ color, share: Math.min(100, l.percentUsed) }, { color: TRACK, share: Math.max(0, 100 - l.percentUsed) }]} />
        {pct(l.percentUsed, color)}
        <Box marginLeft={2} flexShrink={1}>
          <Text color={MUTED} wrap="truncate-end">{note}</Text>
        </Box>
      </Box>
    )
  })

  const group = (name: string) => snap.categories.find(c => c.kind === 'used' && c.name === name)?.tokens ?? 0
  const buffer = snap.categories.filter(c => c.kind === 'buffer').reduce((sum, c) => sum + c.tokens, 0)
  const free = Math.max(0, snap.window - snap.tokens - buffer)
  const contextColor = COLOR[levelOf(snap.percent, CONTEXT_AMBER_AT, CONTEXT_RED_AT)]

  return (
    <Box flexDirection="column">
      {stale ? <Text color={AMBER} wrap="wrap">{stale}</Text> : null}
      {windows.length === 0 && !stale ? <Text color={MUTED}>Usage limits show after the first reply.</Text> : null}
      {limitRows}
      <Box flexDirection="row">
        <Box width={LABEL} flexShrink={0}>
          <Text bold>Context</Text>
        </Box>
        <Bar
          ui={ui}
          cells={cells}
          segments={[
            { color: MESSAGES, share: group('Messages') },
            { color: TOOLS, share: group('Tools') },
            { color: OTHER, share: group('Other') + buffer },
            { color: TRACK, share: free },
          ]}
        />
        {pct(snap.percent, contextColor)}
        <Box marginLeft={2} flexShrink={1}>
          <Text color={MUTED} wrap="truncate-end">{`${tokens(free)} free of ${tokens(snap.window)}`}</Text>
        </Box>
      </Box>
      <Box flexDirection="row" marginLeft={LABEL} columnGap={2}>
        <Text color={MESSAGES}>{`Messages ${tokens(group('Messages'))}`}</Text>
        <Text color={TOOLS}>{`Tools ${tokens(group('Tools'))}`}</Text>
        <Text color={MUTED}>{`Other ${tokens(group('Other'))}`}</Text>
      </Box>
    </Box>
  )
}
