import { atom, read, update } from 'claude-code'
import type { ElementTable, EngineInterface, RenderNode } from 'claude-code'

import type { LastTurn, Limit, Limits } from '../../types'
import type { TabInfo, TabRequest } from '../tab'
import { MUTED, Stepper, Switch } from '../widgets'

const DEFAULTS: Limits = { lines: { value: 3, isOn: false }, tools: { value: 3, isOn: false } }
const STORE_KEY = 'limits'

const limitsAtom = atom({ plugin: 'dock', key: 'limits' } as const, DEFAULTS)
const lastAtom = atom({ plugin: 'dock', key: 'last' } as const, null as LastTurn | null)

type Which = keyof Limits

function countLines(text: string): number {
  const trimmed = text.trim()
  return trimmed === '' ? 0 : trimmed.split('\n').length
}

function instruction(limits: Limits): string {
  const rules: string[] = []
  if (limits.tools.isOn) {
    rules.push(
      `- At most ${limits.tools.value} tool calls this turn, subagents included; the harness denies any call beyond that. ` +
        'Spend them only on what the conclusion needs, nothing outside the request unless it fails. ' +
        'When the budget runs out, answer with what you have and say in one line what is still unknown.',
    )
  }
  if (limits.lines.isOn) {
    rules.push(
      `- Final answer at most ${limits.lines.value} lines: the conclusion only (for a test: pass, or fail with the reason), ` +
        'plus ids needed to look it up again. No step-by-step narration, no tables unless they fit the limit. ' +
        'If a decision is needed from the user, ask it in one line.',
    )
  }
  return 'Answer limits set by the user for every turn until changed:\n' + rules.join('\n')
}

async function setLimit($: EngineInterface, which: Which, fn: (l: Limit) => Limit) {
  await update($, limitsAtom, limits => ({ ...limits, [which]: fn(limits[which]) }))
  await $.store.set(STORE_KEY, await read($, limitsAtom))
}

const short = (l: Limit) => (l.isOn ? String(l.value) : '-')

// module scope: a reload starts the count over, as a new turn would
let toolCalls = 0
let wasDenied = false

export const LIMIT: TabInfo = { id: 'limit', title: 'Limit' }

export async function limitTab($: EngineInterface, req: TabRequest): Promise<unknown> {
  switch (req.kind) {
    case 'sessionStart': {
      // the values carry over; every cap starts off, so a session never begins capped unseen
      const saved = (await $.store.get(STORE_KEY)) as Limits | undefined
      if (saved !== undefined) {
        await update($, limitsAtom, () => ({ lines: { ...saved.lines, isOn: false }, tools: { ...saved.tools, isOn: false } }))
      }
      return
    }
    case 'promptSubmit':
      toolCalls = 0
      wasDenied = false
      return
    case 'toolCall': {
      const { tools } = await read($, limitsAtom)
      if (tools.isOn && toolCalls >= tools.value) {
        wasDenied = true
        return (
          `dock: tool budget of ${tools.value} calls for this turn is used up. ` +
          'Answer now with what you have; say in one line what is still unknown.'
        )
      }
      toolCalls += 1
      return undefined
    }
    case 'promptCompose': {
      const limits = await read($, limitsAtom)
      if (!limits.lines.isOn && !limits.tools.isOn) return undefined
      return { id: 'dock:limits', text: instruction(limits), scope: 'session' }
    }
    case 'turnComplete': {
      if (req.e.agentId !== undefined) return
      const { lines } = await read($, limitsAtom)
      const count = countLines(req.e.answer)
      const last: LastTurn = { tools: toolCalls, lines: count, hit: wasDenied || (lines.isOn && count > lines.value) }
      await update($, lastAtom, () => last)
      return
    }
    case 'summary': {
      const limits = await read($, limitsAtom)
      return `L${short(limits.lines)} T${short(limits.tools)}`
    }
    case 'attention': {
      const last = await read($, lastAtom)
      if (last?.hit) return 'alert'
      const limits = await read($, limitsAtom)
      return limits.lines.isOn || limits.tools.isOn ? 'warn' : 'none'
    }
    case 'render':
      return render($, req.ui)
    default:
      return undefined
  }
}

async function render($: EngineInterface, ui: ElementTable): Promise<RenderNode> {
  const { Box, Text } = ui
  const limits = await read($, limitsAtom)
  const last = await read($, lastAtom)

  const row = (which: Which, label: string) => {
    const limit = limits[which]
    return (
      <Box flexDirection="row" columnGap={3}>
        <Box width={6} flexShrink={0}>
          <Text bold>{label}</Text>
        </Box>
        <Stepper
          ui={ui}
          id={which}
          text={String(limit.value)}
          isOn={limit.isOn}
          onDec={() => setLimit($, which, l => ({ value: Math.max(1, l.value - 1), isOn: true }))}
          onInc={() => setLimit($, which, l => ({ value: l.value + 1, isOn: true }))}
        />
        <Switch ui={ui} id={which} isOn={limit.isOn} onToggle={() => setLimit($, which, l => ({ ...l, isOn: !l.isOn }))} />
      </Box>
    )
  }

  return (
    <Box flexDirection="column">
      {row('lines', 'Lines')}
      {row('tools', 'Tools')}
      <Text> </Text>
      <Text color={MUTED}>{last === null ? 'last turn · none yet' : `last turn · ${last.lines} lines · ${last.tools} tools`}</Text>
    </Box>
  )
}
