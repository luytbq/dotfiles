---
name: askjev
description: "Ask TypeSafe Jev to break a tie when two or more paths are still plausible and you are about to pick arbitrarily. Returns typed Choice / Score / Noul answers with confidence."
license: MIT
---

# Ask Jev

TypeSafe Jev is a System One decision model, not a chat model. It returns typed Choice / Score / Noul answers with probabilities. Use it as a **tiebreaker** when two or more paths are still plausible after tools and user intent are accounted for. Code (this skill's script) owns the workflow; Jev only supplies the judgment.

Do not use Jev to generate text, plans, or explanations. It will not.

## When to Use

Load and call this skill when:

- Two or more next actions, implementations, classifications, or candidates are still reasonable.
- You are about to pick arbitrarily (coin-flip, "feels slightly better," first option in a list).
- You need a calibrated yes/no (sufficient evidence? on-topic? blocked page vs empty?) before branching.
- You want a second axis: **what** (choice/score/noul) plus **whether to act** (confidence / grey-zone).

Don't use for:

- Facts you can look up, compute, or read from a file in one tool call.
- Anything the user already decided.
- Safety, policy, legal, or permission questions (user instructions and CLAUDE.md win; Jev cannot override them).
- Open-ended reasoning, writing, or multi-hop plans - decompose or just think.
- Secrets, credentials, or raw private payloads as `state`.

If a tool answer in ~30s would settle it, skip Jev.

## Prerequisites

- `TYPESAFE_AI_KEY` exported in the environment Claude Code runs in (shell profile, or `env` in `~/.claude/settings.json`). The script does not read any `.env` file.
- Disable (any one is enough): set `ASKJEV_DISABLED=1`, or delete this skill directory.
- No extra packages. Script is stdlib-only against `POST https://api.typesafe.ai/v1/systemone`.
- Default model: `jev-latest` (override with `TYPESAFE_DEFAULT_MODEL` or `--model`).
- Every call (including failed and disabled ones) is logged to SQLite at `~/.claude/askjev/askjev.db` (override with `ASKJEV_DB`, turn off with `ASKJEV_LOG=0`). Logging is best-effort: a write failure prints a warning to stderr and never changes stdout or the exit code.

## How to Run

Script path:

```
ASKJEV="$HOME/.claude/skills/ask-jev-skill/scripts/askjev.py"
```

Canonical: pipe a payload JSON to the script via the Bash tool:

```bash
python3 "$HOME/.claude/skills/ask-jev-skill/scripts/askjev.py" --payload - <<'JSON'
{ ...payload... }
JSON
```

Payload shape (same as TypeSafe HTTP, plus an optional `meta` that is logged and never sent to Jev):

```json
{
  "meta": {"why": "One sentence naming the fork being decided", "tag": "crawl"},
  "state": {"goal": "...", "options_context": "...", "constraints": "..."},
  "questions": {
    "path": {
      "type": "choice",
      "instructions": "Which next action should Claude take?",
      "criteria": {
        "a": "...",
        "b": "...",
        "other": "None of the named options fit"
      }
    }
  }
}
```

Helpers:

```
python3 "$ASKJEV" choice --why 'curl or browser for the vendor login page' --tag crawl \
  --state '...' --question 'Which path?' --option curl="static page" --option browser="JS app"
python3 "$ASKJEV" noul --state '...' --question 'Is evidence sufficient to answer without more tools?'
python3 "$ASKJEV" score --state '...' --question 'How on-topic is this source?' --level 'off' --level 'partial' --level 'direct'
```

Stdout is one JSON object: `answers`, `verdicts` (act/escalate), `usage`, `model`, `call_id` (log row id, `null` when not logged). Exit `0` all gates act; `3` at least one escalate (answers still present); `2` disabled/missing key; `1` request error.

Live eval (does not change config, takes a few minutes, run with a 300s Bash timeout):

```
python3 "$HOME/.claude/skills/ask-jev-skill/scripts/eval.py"
```

## Procedure

1. **Confirm it is a judgment.** Lookup / user intent / policy → do that instead. Done when you can name the fork in one sentence.
2. **Pack state as named JSON fields**, not a vibes paragraph: goal, constraints, evidence, the options under consideration. No secrets (state is also stored in plain text in the local log). Include an `other` / `none` choice when the list may not cover it. Always set `why` (`--why` or `meta.why`) to the one-sentence fork from step 1, and a short `tag` for the kind of work; the log is reviewed by a human and is useless without them.
3. **Ask atomic questions in one call.** Independent dimensions = separate questions (they run in parallel). Do not cram a plan into one Choice.
4. **Run `scripts/askjev.py`.** Completion: JSON on stdout with `verdicts`.
5. **Gate on verdicts, not vibes.**
   - Choice/Score `gate=act` (default min confidence `0.6`): take `decision`.
   - `gate=escalate`: gather more state, ask the user, or pick a reversible default. Do not silently take the argmax.
   - Noul `yes` (`noul>=0.7`) / `no` (`<=0.3`) / `uncertain` (grey). Uncertain = escalate.
   - Destructive or hard-to-undo work: require confidence `>=0.85` or user confirmation even if `act`.
6. **Log one line** in your reply when Jev moved the decision: `call_id`, question, decision, confidence/noul, whether you acted. Skip the essay.

## Pitfalls

- Jev does not explain itself. If you need a rationale, you already have it in `state`; do not prompt Jev for prose.
- Docs examples can disagree with the current `jev-*` version. Trust live `confidence` more than a remembered label.
- Low confidence often means the options overlap or the state is thin, not that the model is broken. Tighten criteria (`what` / `not_for`) or split the question.
- A multi-issue ticket can still come back as one Choice with high confidence (Jev picks a primary). Detect several labels with separate Noul questions, not by waiting for Choice confidence to drop.
- Score can land on the right level with mediocre `confidence` when probability leaks to neighbors. Gate on both the score and confidence for high-stakes branches.
- Noul has no `confidence` field. A value near `0.5` is a coin-flip, not "medium yes."
- Question ids are not sent to the model. Put the full meaning in `instructions` + `criteria`.
- Do not install `typesafe-sdk` just for this skill. HTTP via the script keeps the whole thing one directory.
- Rate limits: `429` / `529` - the script retries with backoff. Persistent failure → proceed without Jev and say so.

## Call Log and UI

For the human, not for Claude during a task. Do not open the UI or query the log unless the user asks.

```bash
python3 "$HOME/.claude/skills/ask-jev-skill/scripts/jevlog_ui.py" --open      # http://127.0.0.1:8765
python3 "$HOME/.claude/skills/ask-jev-skill/scripts/jevlog.py" info
python3 "$HOME/.claude/skills/ask-jev-skill/scripts/jevlog.py" stats --days 30
python3 "$HOME/.claude/skills/ask-jev-skill/scripts/jevlog.py" purge --older-than-days 90 --dry-run
```

- UI pages: dashboard (volume, failure and escalate rates, latency, confidence/noul histograms, gate split per question type, top repo/tag), call list, call detail, purge by date range (VACUUM afterwards).
- Search: a quick box (case- and Vietnamese-diacritic-insensitive), plus a raw SQLite `WHERE` clause over the view `search_v`, e.g. `why LIKE '%crawl%' AND state NOT LIKE '%captcha%'`. Extra functions: `ulike(col, pattern)` and `col REGEXP 'py-regex'`. The clause runs on a read-only connection with an authorizer that allows reads of the log tables only, and a 2s time limit.
- Calls from `scripts/eval.py` are logged with `source = 'eval'` and hidden unless "gồm cả eval" is ticked.
- The server binds to 127.0.0.1 only and rejects foreign `Host` headers and cross-site POSTs.

## Verification

- `python3 scripts/askjev.py --payload ...` returns `model` starting with `jev-` and one answer per question.
- `ASKJEV_DISABLED=1 python3 scripts/askjev.py --payload ...` exits `2` and does not call the network.
- After a successful call, `python3 scripts/jevlog.py info` shows `calls` increased by one, and stdout carried a numeric `call_id`.
- `ASKJEV_DB=/dev/null/x.db python3 scripts/askjev.py ...` still returns the normal answer and exit code, with `call_id: null` and a warning on stderr.
- `python3 scripts/eval.py` reports per-case pass/fail against live Jev. Treat a failing *expected label* with high confidence as a real reliability issue; a failing label with low confidence is an escalate-path success if the eval marks it that way.
