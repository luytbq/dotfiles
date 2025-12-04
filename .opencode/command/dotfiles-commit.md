---
description: Commit and push dotfiles changes to the repository.
agent: build
model: github-copilot/gpt-5.1-codex-mini
---
Do not need to read `AGENTS.md` for this task.

# Steps:
1. Check for staged changes using `dotfiles diff --staged`.
2. If there are no staged changes, exit the process.
3. Analyze the staged changes to identify the files modified.
4. Determine the appropriate scope for the commit message based on the files modified.
5. Construct the commit message in the format: `{scope}: {description}`.
  scope: indicates which tool or configuration was affected (e.g., nvim plugin, nvim config, bash, opencode, kitty, etc.)
  description: should provide which functionality was changed and what was done (add new user command 'SetTabStop')

6. Use `dotfiles commit -m "{commit message}"` to commit the changes.
7. Push the changes to the remote repository using `dotfiles push`.

# Example Commit Messages:
- `nvim plugin: update coc.nvim to latest version`
- `bash: add new alias for git`
- `kitty: update color scheme configuration`
- `opencode: change keymap for 'command_list'`


