/** value: the cap when on; isOn false keeps value for when it is turned back on */
export type Limit = { value: number; isOn: boolean }
export type Limits = { lines: Limit; tools: Limit }
export type LastTurn = { tools: number; lines: number }

declare module 'claude-code' {
  interface PluginState {
    'answer-limit': { limits: Limits; last: LastTurn | null }
  }
}
