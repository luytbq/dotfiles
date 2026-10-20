# askjev

Claude Code skill: call TypeSafe **Jev** (`jev-latest`) as a typed tiebreaker. Jev is not a chat model. It returns Choice / Score / Noul answers with probabilities so an agent can act or escalate.

## Install

Place this directory at `~/.claude/skills/ask-jev-skill/`.

Export `TYPESAFE_AI_KEY` in the environment Claude Code runs in (shell profile, or `env` in `~/.claude/settings.json`). Never commit the key.

## Disable

Set `ASKJEV_DISABLED=1`, or delete the skill directory.

## Run

```bash
python3 scripts/askjev.py choice --state '...' --question 'Which path?' \
  --option a='...' --option b='...'
python3 scripts/eval.py   # live reliability suite (needs the API key)
```

See `SKILL.md` for when to call Jev, confidence gates, and pitfalls.
