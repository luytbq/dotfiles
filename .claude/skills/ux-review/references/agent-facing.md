# Agent-Facing Interface Checklist

Read after Step 2 of the core workflow, when the medium is agent. Applies to skills, slash commands, MCP tool definitions, and any tool an LLM calls rather than a person.

The driver here is a model with no memory of yesterday, no ability to ask a follow-up mid-call, and a hard budget on context. Those three constraints set every item below.

## Selection: does it get chosen at the right time?

An agent-facing interface fails first at selection, not at execution. If the description does not match how the need actually arises, the tool is never called and nothing else matters.

- The description states when to use it, not only what it does. Capability alone does not trigger selection.
- It uses the words a user would actually type, including the ones they type instead of the correct term.
- It states when not to use it, and names the neighbouring tool that fits instead. Every such reference must point at something that exists; a dead reference is a hard defect.
- No two tools on the surface overlap in scope. Overlap produces a coin flip, and the coin flip is invisible in logs.
- The name says the job. A tool named "helper" or "process" is unselectable.

## Parameters

- Every parameter name is self-describing on its own. Nothing called value, data, input, options, or config.
- Enumerations are closed lists in the schema, so the model cannot invent a member.
- Required parameters are genuinely required. Anything the tool can infer, it should infer.
- No parameter's meaning depends on another parameter's value.
- Types constrain what is possible. A string where an enum belongs invites free text.
- Defaults are stated in the description, because the model decides whether to pass a value based on that text alone.

## Output

Output is charged to context on every call, so volume is a design property, not an implementation detail.

- Return what the caller needs to act on, and nothing else. Full dumps crowd out the reasoning that was going to use them.
- Lead with the answer. Preamble gets truncated or skimmed.
- Output is stable in shape across calls, so the caller can rely on where to look.
- Cap unbounded results and say plainly that truncation happened, with a way to get the rest.
- Do not return raw pass-through of an upstream payload when a summary would serve.

## Errors the agent can recover from

The agent cannot ask a human what went wrong. The error message is the entire repair channel.

- Say which parameter was wrong and what was expected, in the same message.
- Distinguish "you called this wrong" from "this failed and a retry may work" from "this cannot work here". These lead to three different next moves.
- Include the valid options when a value was rejected.
- Never fail silently or return empty on error. An empty success is read as a real answer.

## Instruction quality, for skills

- Steps are ordered and each is verifiable, so the agent can tell whether it completed one.
- Prescribe what to do, not background theory. Rationale earns its place only where it changes a decision.
- Keep the entry file small and push detail into references the agent loads on demand. Anything loaded every run costs on every run.
- State the output format concretely, and give a template if the shape matters.
- Prohibitions are explicit. Assume nothing is obvious.

## Common findings to look for

| Symptom | Usual fix |
|---|---|
| The tool is never selected | Rewrite the description around the trigger, not the capability |
| Two tools chosen at random for the same need | Merge them, or narrow both scopes |
| The agent passes wrong enum values | Close the enum in the schema |
| Context fills up after a few calls | Cap and summarize the output |
| The agent retries a call that can never succeed | Distinguish error classes in the message |
| Every run loads unused instructions | Split into references |
| Points at a tool or skill that does not exist | Fix or remove the reference |
