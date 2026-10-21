import { atom, read, update } from 'claude-code'
import type { EngineInterface, PromptComposeSection, Register } from 'claude-code'

import type { TabInfo, TabReplyOf, TabRequest } from './tab'
import { LIMIT, limitTab } from './tabs/limit'
import { USAGE, usageTab } from './tabs/usage'
import { Rule, TabBar } from './widgets'

// A new tab is a module under ./tabs: its TabInfo goes in TABS (the order drawn)
// and its handler in a case of dispatch.
const TABS: TabInfo[] = [USAGE, LIMIT]

async function dispatch($: EngineInterface, id: string, req: TabRequest): Promise<unknown> {
  switch (id) {
    case USAGE.id:
      return usageTab($, req)
    case LIMIT.id:
      return limitTab($, req)
    default:
      return undefined
  }
}

async function ask<R extends TabRequest>($: EngineInterface, id: string, req: R): Promise<TabReplyOf<R['kind']>> {
  return (await dispatch($, id, req)) as TabReplyOf<R['kind']>
}

const isOn = atom({ plugin: 'dock', key: 'isOn' } as const, true)
const activeTab = atom({ plugin: 'dock', key: 'activeTab' } as const, TABS[0]!.id)

const tabOf = (id: string): TabInfo => TABS.find(t => t.id === id) ?? TABS[0]!

async function select($: EngineInterface, id: string): Promise<void> {
  await update($, activeTab, () => id)
  await $.store.set('activeTab', id)
}

async function step($: EngineInterface, delta: number): Promise<void> {
  const index = TABS.indexOf(tabOf(await read($, activeTab)))
  await select($, TABS[(index + delta + TABS.length) % TABS.length]!.id)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'dock', description: 'Show or hide the dock above the prompt' })
    const result = await next(e)
    const savedOn = (await $.store.get('isOn')) as boolean | undefined
    if (savedOn !== undefined) await update($, isOn, () => savedOn)
    // a tab saved by an older build may be gone: the first tab then
    const savedTab = (await $.store.get('activeTab')) as string | undefined
    if (savedTab !== undefined) await update($, activeTab, () => tabOf(savedTab).id)
    for (const tab of TABS) await ask($, tab.id, { kind: 'sessionStart' })
    return result
  })

  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    for (const tab of TABS) await ask($, tab.id, { kind: 'sessionMeasure' })
    return result
  })

  on('prompt.submit', async ($, e, next) => {
    for (const tab of TABS) await ask($, tab.id, { kind: 'promptSubmit' })
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    for (const tab of TABS) {
      const deny = await ask($, tab.id, { kind: 'toolCall', e })
      if (deny !== undefined) return { deny }
    }
    return next(e)
  })

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)
    const added: PromptComposeSection[] = []
    for (const tab of TABS) {
      const section = await ask($, tab.id, { kind: 'promptCompose' })
      if (section) added.push(section)
    }
    return added.length === 0 ? composed : { sections: [...composed.sections, ...added] }
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    for (const tab of TABS) await ask($, tab.id, { kind: 'turnComplete', e })
    return result
  })

  on('command.run', { command: 'dock' }, async $ => {
    const now = !(await read($, isOn))
    await update($, isOn, () => now)
    await $.store.set('isOn', now)
    return { text: now ? 'Dock shown.' : 'Dock hidden.' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || !(await read($, isOn))) return next(e)
    // the band is shared by every plugin: what the plugins beneath draw goes under this one
    const below = await next(e)
    const ui = $.ui.resolve(e)
    const { Box } = ui
    const width = Math.max(20, e.props.bodyColumns)
    const active = tabOf(await read($, activeTab))
    const labels = []
    for (const tab of TABS) {
      const summary = await ask($, tab.id, { kind: 'summary' })
      const attention = await ask($, tab.id, { kind: 'attention' })
      labels.push({ ...tab, summary, attention })
    }
    const content = await ask($, active.id, { kind: 'render', ui, width: width - 1 })

    return (
      <Box flexDirection="column">
        <TabBar ui={ui} tabs={labels} activeId={active.id} onSelect={id => select($, id)} onStep={delta => step($, delta)} />
        <Rule ui={ui} width={width} />
        <Box paddingLeft={1}>{content}</Box>
        {below}
      </Box>
    )
  })
}
