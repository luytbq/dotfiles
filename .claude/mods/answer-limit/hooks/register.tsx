import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { LastTurn, Limit, Limits } from '../types'

const DEFAULTS: Limits = { lines: { value: 3, isOn: false }, tools: { value: 3, isOn: false } }
const STORE_KEY = 'limits'

const limitsAtom = atom({ plugin: 'answer-limit', key: 'limits' } as const, DEFAULTS)
const lastAtom = atom({ plugin: 'answer-limit', key: 'last' } as const, null as LastTurn | null)

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

export const register: Register = on => {
  let toolCalls = 0

  on('session.start', async ($, e, next) => {
    const saved = (await $.store.get(STORE_KEY)) as Limits | undefined
    if (saved !== undefined) {
      await update($, limitsAtom, () => saved)
    }
    return next(e)
  })

  on('prompt.submit', ($, e, next) => {
    toolCalls = 0
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    const { tools } = await read($, limitsAtom)
    if (tools.isOn && toolCalls >= tools.value) {
      return {
        deny:
          `answer-limit: tool budget of ${tools.value} calls for this turn is used up. ` +
          'Answer now with what you have; say in one line what is still unknown.',
      }
    }
    toolCalls += 1
    return next(e)
  })

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)
    const limits = await read($, limitsAtom)
    if (!limits.lines.isOn && !limits.tools.isOn) {
      return composed
    }
    const section = { id: 'answer-limit:limits', text: instruction(limits), scope: 'session' } as const
    return { sections: [...composed.sections, section] }
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      const last: LastTurn = { tools: toolCalls, lines: countLines(e.answer) }
      await update($, lastAtom, () => last)
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) {
      return next(e)
    }
    // The band is shared by every plugin: draw the tree of the plugins beneath too, not over it
    const below = await next(e)
    const limits = await read($, limitsAtom)
    const last = await read($, lastAtom)
    const { Box, Button, Text } = $.ui.resolve(e)

    const controls = (which: Which, label: string, keys: [string, string, string]) => {
      const limit = limits[which]
      return [
        <Text key={`${which}-label`}>
          {label}: {limit.isOn ? String(limit.value) : 'off'}{' '}
        </Text>,
        <Button
          key={`${which}-dec`}
          label="-"
          hotkey={keys[0]}
          onPress={() => setLimit($, which, l => ({ value: Math.max(1, l.value - 1), isOn: true }))}
        />,
        <Text key={`${which}-sp1`}> </Text>,
        <Button
          key={`${which}-inc`}
          label="+"
          hotkey={keys[1]}
          onPress={() => setLimit($, which, l => ({ value: l.value + 1, isOn: true }))}
        />,
        <Text key={`${which}-sp2`}> </Text>,
        <Button
          key={`${which}-toggle`}
          label={limit.isOn ? 'off' : 'on'}
          hotkey={keys[2]}
          onPress={() => setLimit($, which, l => ({ ...l, isOn: !l.isOn }))}
        />,
      ]
    }

    return (
      <Box flexDirection="column">
        <Box>
        <Text dimColor>Answer limit: </Text>
        {controls('lines', 'Lines', ['a', 's', 'd'])}
        <Text dimColor> · </Text>
        {controls('tools', 'Tool calls', ['j', 'k', 'l'])}
        {last !== null ? <Text dimColor>  last: {last.lines} lines, {last.tools} tools</Text> : null}
        </Box>
        {below}
      </Box>
    )
  })
}
