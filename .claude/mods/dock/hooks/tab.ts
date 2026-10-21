import type { ElementTable, PromptComposeSection, RenderNode, ToolCallInput, TurnCompleteInput } from 'claude-code'

export type Attention = 'none' | 'warn' | 'alert'

export type TabInfo = { id: string; title: string }

/**
 * What the dock asks of a tab. A tab is one exported function taking $ and a
 * request; the dock calls it by name, as the engine only lets $ reach the
 * plugin's own named functions.
 *
 * The engine takes one hook per event from a plugin, so a tab never hooks an
 * event itself: the dock hooks each once and asks every tab in turn, after the
 * engine has run, except toolCall, which is asked before and may deny.
 */
export type TabRequest =
  | { kind: 'summary' }
  | { kind: 'attention' }
  | { kind: 'render'; ui: ElementTable; width: number }
  | { kind: 'sessionStart' }
  | { kind: 'sessionMeasure' }
  | { kind: 'promptSubmit' }
  | { kind: 'toolCall'; e: ToolCallInput }
  | { kind: 'promptCompose' }
  | { kind: 'turnComplete'; e: TurnCompleteInput }

/**
 * The answer to each request kind; a kind not listed answers nothing. summary
 * is a few characters shown beside the title, kept current while the tab is
 * hidden; a toolCall text denies the call with it; a promptCompose section is
 * added at the end of the system prompt.
 */
export type TabReply = {
  summary: string
  attention: Attention
  render: RenderNode
  toolCall: string | undefined
  promptCompose: PromptComposeSection | undefined
}

export type TabReplyOf<K extends TabRequest['kind']> = K extends keyof TabReply ? TabReply[K] : void
