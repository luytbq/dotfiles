---
name: ux-review
description: Review the user experience of any interface - CLI tools, HTTP/RPC APIs, web UI, or agent-facing tools and skills. Evaluates discoverability, naming, explicitness, defaults, feedback, error quality, and safety, then reports findings with concrete before/after signatures. Use when designing or critiquing how something is invoked, configured, or driven, not just how it looks.
tags:
  - ux
  - interface-design
  - api-design
  - cli-design
  - usability
  - design-review
triggers:
  - ux review
  - interface review
  - usability review
  - design critique
  - api design review
  - cli design review
  - review the interface
keywords:
  - UX review
  - interface design
  - developer experience
  - ergonomics
  - review
---

# UX Review

UX is the quality of the interface between a system and whoever drives it. That driver may be a person clicking, a person typing a command, another program, or an LLM agent. A CLI has UX. An HTTP endpoint has UX. A config file format has UX. A tool description has UX.

This skill reviews any of those at a high level, using one medium-agnostic core plus a thin per-medium checklist.

## When to Use This Skill

- Designing a new interface, before it has callers and is cheap to change
- Critiquing an existing interface that people keep getting wrong
- Reviewing a change that adds or alters a flag, endpoint, parameter, or screen
- Deciding between two candidate signatures for the same capability

Not for pure visual and aesthetic critique of a screen. This skill judges the contract, not the styling.

## Scope

Review and propose only. Do not change the interface as part of the review. Public interfaces have callers, so the decision to break them belongs to the owner. Output findings; let the owner choose.

Write the report in English regardless of the language of the conversation. Proposed strings that the interface itself shows to its own users stay in the language that interface already speaks.

## Arguments

Invoke as: ux-review TARGET [MEDIUM]

TARGET is a path, command name, endpoint, or description of the surface. MEDIUM is one of cli, api, gui, agent. If MEDIUM is omitted, infer it in Step 0.

## Workflow

### Step 0: Frame the surface

Establish two things before reviewing anything.

Medium. Which of cli, api, gui, agent. A surface can have more than one; review each separately rather than blending them.

Driver. Who or what produces the calls, because this reorders every priority below.

| Driver | What they need most |
|---|---|
| Novice human, uses it once | Discoverability, safe defaults, error quality |
| Expert human, uses it daily | Economy of keystrokes, consistency, composability |
| Script or another program | Stable contract, machine-readable output, exit codes, idempotency |
| LLM agent | Self-describing names, cheap output, errors it can recover from alone |

Then find the real callers. Grep the repo, dotfiles, CI config, and neighbouring scripts for actual invocations. The count sets the price of every proposal: no callers means propose freely, many means each After needs a migration path. It also corrects the driver you assumed.

Then write down the top three tasks a driver actually comes here to accomplish. If you cannot name three, ask the owner rather than guessing.

### Step 1: The Invocation Test

This is the highest-yield step. Do it before any checklist.

For each of the three tasks, write out the literal thing the driver must produce with their own hands: the whole command line, the whole HTTP request, the whole click path, the whole tool call. Real values, not placeholders.

Then read it cold, as someone who has not seen the docs, and account for every single token. Anything you cannot explain from the invocation alone is a finding.

```
tool input.md 10          # what is 10? a count, a limit, a timeout, a page?
tool -i input.md -n 10    # self-describing at the call site
```

The same test generalizes past CLIs:

- A boolean positional argument in a function call: process(path, true, false)
- An unnamed field in a request body whose meaning depends on another field
- A button whose label is an icon with no accessible name
- A tool parameter named "value" or "data" or "options"

An interface passes this test when a reader can reconstruct the intent from a single call, with no documentation and no source.

Then run them. An invocation you can execute safely, execute: it converts an opinion into an observation, and observed findings are the ones an owner acts on.

- Read-only paths (status, list, get, --help, GET) run directly.
- Mutating paths: shim the external command the target drives, put the shim first on PATH, and drive the real interface against it. This exercises the real dispatch, ordering, messages, and exit codes with no real side effects.
- Never mutate shared, production, or another person's state to produce a finding. If a path cannot be reached safely, say so and leave it inferred.

Tag each finding observed if you reproduced it, inferred if you only read it off the source. Say in the report which mutating paths you did not exercise.

### Step 2: Score the ten axes

These are Nielsen's ten heuristics restated so they apply to any interface, not only to screens.

| Axis | Check |
|---|---|
| Discoverability | Can the driver learn what is possible from the interface itself, without reading source? And does that list of possibilities come from the system, or from a copy baked into the source? |
| Vocabulary | Do names match the domain language? One concept, one word, used consistently. |
| Explicitness | Does a single call explain itself, or does meaning hide in position and order? |
| Defaults and economy | Does the common case need zero configuration, and does every option that exists justify itself? |
| Feedback | Does the driver know what happened, what changed, and what is still running? |
| Error quality | Does a failure say what failed, why, and the next action, carrying the identifiers needed to act? |
| Safety | Are destructive or irreversible actions guarded, previewable, and idempotent where possible? |
| Convention | Does it follow the ecosystem's existing conventions instead of inventing new ones? |
| Progressive disclosure | Is the simple case simple and the complex case still possible, with no cliff between them? |
| Composability | Can another program drive this without screen-scraping or guessing? |

Note the axes that do not apply to the medium at hand and move on. A silent axis is not a finding.

### Step 3: Run the medium checklist

Read exactly one file, matching the medium from Step 0. Do not read the others.

| Medium | File |
|---|---|
| cli | references/cli.md |
| api | references/http-api.md |
| gui | references/gui.md |
| agent | references/agent-facing.md |

### Step 4: Rank by cost

Rank by what the flaw actually costs the driver, not by how wrong it feels.

| Rank | Meaning |
|---|---|
| Blocking | The driver cannot accomplish the task, or silently accomplishes a different one |
| Recurring friction | It works, but every single use requires docs, source, or trial and error |
| Trap | It works today, but is easy to misuse or breaks once scripted |
| Polish | Everything else |

A short list of blocking findings beats a wall of polish. If a rank is empty, say so and drop the heading.

### Step 5: Report

Every finding must carry a concrete proposed signature. A finding without a specific After is not a finding, it is a feeling. Delete it.

The After is the part that gets applied, so it costs the most when wrong. When it depends on the behaviour of an external command, API, or library, probe that behaviour before writing it. If you cannot, still write the After, and mark it unverified. A confident wrong After is worse than a missing finding: it reads as authoritative and it ships.

```markdown
## UX Review: [surface name]

**Medium:** [cli|api|gui|agent] · **Driver:** [who produces the calls]

### Summary
[2-3 sentences: what this interface is good at, and the one thing most worth changing]

### Invocation Test
| Task | Current invocation | Reads clearly? |
|------|-------------------|----------------|
| [task] | [literal call] | [yes / no, and which token fails] |

### Blocking
| # | Finding | Axis | Evidence | Before | After |
|---|---------|------|----------|--------|-------|
| 1 | [what breaks, for whom] | [axis] | [observed / inferred] | [current signature] | [proposed signature] |

### Recurring friction
[same table shape]

### Traps
[same table shape]

### Polish
[one line each, continuing the same numbering, no table]

### Migration notes
[Which proposals break existing callers, and how to ship them: alias the old form,
accept both for a release, or gate behind a major version. Name the callers found
in Step 0. Omit if nothing breaks.]

### Not exercised
[Paths you could not run safely, and what would settle them. Omit if you ran everything.]
```

For a merge request comment, collapse to the three highest-ranked findings as a flat list, each one line: finding, then before, then after.

## Best Practices

- Run the Invocation Test before opening any checklist. It finds most of what matters, and running the invocations is what separates a finding from a guess.
- Review against a real task, not a feature list. Feature lists hide the fact that the common case takes six flags.
- Name the driver out loud. "Good UX" is meaningless without knowing who is driving.
- Prefer one strong proposal over three weak options. If you genuinely cannot choose, say which you would ship and why.
- Check what the interface makes easy to do by accident, not only what it makes possible.
- Count the surface area. An interface with forty options usually has ten that no one has ever set on purpose.
- Do not invent a convention when the ecosystem already has one, even a mediocre one.
