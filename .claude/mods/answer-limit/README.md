# answer-limit

A band above the prompt input that caps, per turn, how many lines the final answer may have and how many tool calls the model may make. Tool calls beyond the budget, subagents included, are denied by the harness; the line cap is an instruction added to the system prompt. Use [-] [+] to change a cap, [on]/[off] to toggle it; with the band focused (ctrl+x tab) the keys are a s d for lines and j k l for tool calls. Settings persist across sessions.
