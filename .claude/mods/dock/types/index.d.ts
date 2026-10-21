export type Category = { name: string; tokens: number; kind: 'used' | 'free' | 'buffer' }
export type PlanLimit = { kind: string; percentUsed: number; resetsAt?: string }
export type Snapshot = {
  window: number
  tokens: number
  percent: number
  categories: Category[]
  limits: PlanLimit[]
  /** when the limit figures were read */
  limitsAt?: number
  /** why the usage service last refused, while it is backed off */
  limitsError?: string
  /** the minute it was taken in: redraws countdowns at least once a minute */
  minute?: number
}

/** value: the cap when on; isOn false keeps value for when it is turned back on */
export type Limit = { value: number; isOn: boolean }
export type Limits = { lines: Limit; tools: Limit }
/** hit: a tool call was denied, or the answer ran past an active line cap */
export type LastTurn = { tools: number; lines: number; hit: boolean }

declare module 'claude-code' {
  interface PluginState {
    dock: {
      isOn: boolean
      activeTab: string
      snapshot: Snapshot | null
      limits: Limits
      last: LastTurn | null
    }
  }
}
