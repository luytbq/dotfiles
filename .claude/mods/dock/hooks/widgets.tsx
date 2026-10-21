import type { ElementTable, RenderNode } from 'claude-code'

import type { Attention } from './tab'

export const MUTED = '#8b90a0'
export const GREEN = '#4ade80'
export const AMBER = '#fbbf24'
export const RED = '#f87171'
export const TRACK = '#2d3140'
export const ACCENT = '#5b6ee1'
export const CHIP = '#3a3f4b'
export const WHITE = '#ffffff'

// the empty part of a bar: lighter than TRACK, which is near the terminal's own background
export const RAIL = '#4b5163'

// no icon while all is well: a mark on every tab would drown the one that matters
const ICON: Record<Exclude<Attention, 'none'>, { glyph: string; color: string }> = {
  warn: { glyph: '▲', color: AMBER },
  alert: { glyph: '✖', color: RED },
}

export type TabLabel = { id: string; title: string; summary: string; attention: Attention }

/**
 * Tabs as the question dialog draws them: the active one under a solid accent
 * block, every Text inside it given the same background so the block has no gaps.
 */
export function TabBar(props: {
  ui: ElementTable
  tabs: TabLabel[]
  activeId: string
  onSelect: (id: string) => void
  onStep: (delta: number) => void
}): RenderNode {
  const { Box, Button, Text } = props.ui
  return (
    <Box flexDirection="row">
      <Button key="dock-prev" plain onPress={() => props.onStep(-1)}>
        <Text color={MUTED}>◂</Text>
      </Button>
      <Text> </Text>
      {props.tabs.map(tab => {
        const isActive = tab.id === props.activeId
        const icon = tab.attention === 'none' ? undefined : ICON[tab.attention]
        const bg = isActive ? ACCENT : undefined
        // The pointer inverts a Button: every Text turns one color under it first, so
        // the inverted tab is one solid block, not a patchwork of its colors
        const hover = { color: isActive ? WHITE : ACCENT, dimColor: false }
        return (
          <Box key={`dock-tabbox-${tab.id}`} flexShrink={0}>
            <Button key={`dock-tab-${tab.id}`} plain onPress={() => props.onSelect(tab.id)}>
              <Text backgroundColor={bg} hover={hover}> </Text>
              {icon ? (
                <Text backgroundColor={bg} color={icon.color} hover={hover}>
                  {`${icon.glyph} `}
                </Text>
              ) : null}
              <Text backgroundColor={bg} color={isActive ? WHITE : undefined} bold={isActive} dimColor={!isActive} hover={hover}>
                {tab.title}
              </Text>
              <Text backgroundColor={bg} color={isActive ? WHITE : MUTED} hover={hover}>{` ${tab.summary} `}</Text>
            </Button>
          </Box>
        )
      })}
      <Text> </Text>
      <Button key="dock-next" plain onPress={() => props.onStep(1)}>
        <Text color={MUTED}>▸</Text>
      </Button>
    </Box>
  )
}

export function Rule(props: { ui: ElementTable; width: number }): RenderNode {
  const { Text } = props.ui
  return <Text color={TRACK}>{'─'.repeat(Math.max(1, props.width))}</Text>
}

/** a thin bar: each share as a run of ━ in its color, what is left as a dim ─ rail */
export function Bar(props: { ui: ElementTable; cells: number; segments: { color: string; share: number }[] }): RenderNode {
  const { Box, Text } = props.ui
  const total = props.segments.reduce((sum, s) => sum + s.share, 0) || 1
  const runs: { color: string; width: number }[] = []
  let used = 0
  for (const seg of props.segments) {
    const width = Math.min(props.cells - used, Math.round((seg.share / total) * props.cells))
    if (width <= 0) continue
    used += width
    const last = runs[runs.length - 1]
    if (last && last.color === seg.color) last.width += width
    else runs.push({ color: seg.color, width })
  }
  if (used < props.cells) runs.push({ color: TRACK, width: props.cells - used })
  return (
    <Box flexDirection="row" width={props.cells} flexShrink={0}>
      {runs.map(run =>
        run.color === TRACK ? <Text color={RAIL}>{'─'.repeat(run.width)}</Text> : <Text color={run.color}>{'━'.repeat(run.width)}</Text>,
      )}
    </Box>
  )
}

/** ‹ value › with the value on a grey chip */
export function Stepper(props: {
  ui: ElementTable
  id: string
  text: string
  isOn: boolean
  onDec: () => void
  onInc: () => void
}): RenderNode {
  const { Box, Button, Text } = props.ui
  return (
    <Box flexDirection="row" flexShrink={0}>
      <Button key={`${props.id}-dec`} plain onPress={props.onDec}>
        <Text color={MUTED}>‹</Text>
      </Button>
      <Text> </Text>
      <Text backgroundColor={CHIP} bold={props.isOn} dimColor={!props.isOn}>{` ${props.text.padStart(2)} `}</Text>
      <Text> </Text>
      <Button key={`${props.id}-inc`} plain onPress={props.onInc}>
        <Text color={MUTED}>›</Text>
      </Button>
    </Box>
  )
}

export function Switch(props: { ui: ElementTable; id: string; isOn: boolean; onToggle: () => void }): RenderNode {
  const { Button, Text } = props.ui
  return (
    <Button key={`${props.id}-toggle`} plain onPress={props.onToggle}>
      {props.isOn ? <Text color={GREEN}>━━● ON </Text> : <Text color={MUTED}>○━━ OFF</Text>}
    </Button>
  )
}
