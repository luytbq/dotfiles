#!/usr/bin/env bash
# Installs the shared Claude Code plugin set on this machine.
# ~/.claude/settings.json is deliberately untracked: Claude Code rewrites it on
# every /model, /config or plugin change, and model/theme differ per machine, so
# syncing it across the mac/linux branches clobbers the other machine's config.
# Safe to re-run: already-added marketplaces and installed plugins are skipped.
set -euo pipefail

MARKETPLACES=(
  anthropics/claude-plugins-official
  # answer-limit, and a fork of anantraghunath/claude-code-usage-quota-mod whose band
  # also draws the plugins beneath it, so both bands show
  "$HOME/.claude/mods"
)

PLUGINS=(
  clangd-lsp@claude-plugins-official
  gopls-lsp@claude-plugins-official
  jdtls-lsp@claude-plugins-official
  frontend-design@claude-plugins-official
  usage-quota@luytbq-mods
  answer-limit@luytbq-mods
)

for m in "${MARKETPLACES[@]}"; do
  claude plugin marketplace add "$m"
done

failed=()
for p in "${PLUGINS[@]}"; do
  claude plugin install "$p" || failed+=("$p")
done

if ((${#failed[@]})); then
  echo "Failed to install: ${failed[*]}" >&2
  exit 1
fi
