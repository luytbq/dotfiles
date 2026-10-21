---
name: subagent-token-saver
description: Rules for cutting token usage in long sessions where one orchestrator spawns many runner and reviewer subagents (pipeline regressions, multi-step prompt test runs, per-item batch analysis, staged review loops). Use when planning or running work that will spawn more than a handful of subagents, when an orchestrator context grows past ~150k tokens, or when the user asks to save tokens, reduce usage, or mentions hitting usage limits.
---

# Subagent token saver

Most of the cost in these sessions comes from three places: subagents running a more expensive model than the job needs, subagents echoing their full output back to the orchestrator, and the orchestrator carrying a huge history from stage to stage. Each rule below targets one of these.

## Rules

1. **Model by role.**
   - Runners, the subagents that produce artifacts, use a mid-tier model (Sonnet).
   - Per-stage reviewers also use the mid-tier model.
   - Run one final whole-run review on the strongest model after the last stage. Skipping it trades away subtle findings for cost, so drop it only if the user agrees.
   - Use the cheapest tier (Haiku) only for mechanical work such as format checks, counting, or grep-style extraction. Never use it when output quality is what is being measured, unless the user asks.

2. **File-based, terse returns.**
   - Every subagent writes its result to a named file.
   - Its reply to the orchestrator is at most 5 lines: the file path, open-question count, finding counts by severity, and the IDs of serious findings.
   - The orchestrator never reads full outputs back. When it needs detail, it greps for the exact line.

3. **Narrow inputs.** Give each subagent only what its step needs: the step's prompt, the shared conventions, and its declared inputs. A reviewer reads only the current stage's prompts and outputs. To cross-check an earlier artifact, it opens that one file, never the whole history.

4. **Orchestrator effort.** The orchestrator mostly dispatches, commits, and tracks state, so medium or low reasoning effort is enough. Keep the subagents' effort where their task needs it.

5. **Fresh orchestrator per stage.**
   - Commit after every step, so durable state lives in git and files, not in the conversation.
   - After each stage commits, end the orchestrator session and start a new one. Give it a short note: what is done (see git log), where to resume, and the standing rules. Don't rerun committed steps.
   - Without a supervisor that can restart sessions, use /compact at each stage boundary instead.

6. **Sequential by default.** Run subagents in parallel only when they are truly independent and the time saved matters. Parallel runs hit session limits together, and a limit that lands mid-step wastes the partial work.

7. **Usage-limit hygiene.**
   - When a limit hits, check git status before resuming.
   - Discard uncommitted partial output from the interrupted step and rerun only that step.
   - A supervisor that is waiting for a limit reset should record the reset time, so it is not woken repeatedly in the meantime.

## Checklist before launching a run

- [ ] Each role has a model assigned: runners, per-stage reviewers, the final review.
- [ ] Each subagent prompt states its output file and the reply limit of 5 lines or fewer.
- [ ] Each reviewer prompt lists exactly which files it may read.
- [ ] The orchestrator effort is set to medium or low.
- [ ] Commit points and stage boundaries are defined, with a restart or compact at each boundary.
- [ ] Rules from this list that the user has declined are written into the run instructions, so they are not reapplied.
