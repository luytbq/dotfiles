# dock

A band above the Claude Code prompt that holds tabs, one kind of information per tab. Built for the terminal.

- Usage: the 5 hour and weekly plan limits (% used, time to reset) and the context window (% used, free space, Messages / Tools / Other). Read from Anthropic's usage service about every 2 minutes, shared across chats, and from each reply in between.
- Limit: caps per turn on the final answer's lines and on tool calls. Tool calls past the cap are denied by the harness, subagents included; the line cap is an instruction added to the system prompt. Use the stepper to change a cap (it turns the cap on) and the switch to turn it on or off.

Each tab label carries a short summary and an icon: a dim check when all is well, a yellow triangle when it needs attention (a limit or the context getting full, a cap turned on), a red cross when it is critical (90% of a limit, 80% of the context, a cap hit last turn).

Click a tab or the arrows at either end to switch. With the band focused (ctrl+x tab), Tab and the arrow keys move between controls and Enter presses one. Type /dock to hide or show the band.

Adding a tab: write a module under hooks/tabs that exports a TabInfo and a handler (see hooks/tab.ts), then add it to TABS and to dispatch in hooks/register.tsx.
