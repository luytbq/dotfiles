---
description: Commit and push dotfiles changes to the repository.
agent: dotfiles
model: github-copilot/gpt-5.1-codex-mini
---
Your task is: Commit and Push my dotfiles Changes.

When running Git commands, replace `git` with `dotfiles`. This wrapper script manages my dotfiles repository.

Commit message convention:
{scope}: {short description}
scope: indicates which tool or configuration was affected (e.g., nvim plugin, nvim config, bash, opencode, kitty, etc.)
