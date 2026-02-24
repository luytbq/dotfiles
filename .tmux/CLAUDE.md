# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A tmux configuration and AI-powered tool launcher system. Provides popup-based tools (English improvement, text summarization, translation) accessible via tmux keybindings, powered by OpenAI API.

## Architecture

- `tool_launcher.sh` — Central dispatcher. Uses fzf to select tools from the `TOOLS` array (format: `"Display Name|script_name.sh"`). Triggered via tmux `prefix + e`.
- `tools/` — Individual tool scripts. Each follows the same pattern:
  1. Source `~/.bash_functions/*.sh` for OpenAI API wrappers
  2. Create temp files with cleanup traps (`stty sane` + `rm`)
  3. Raw terminal input (Ctrl-S to submit)
  4. Call OpenAI function, parse output with awk/sed
  5. Display results with `[y]` copy / `[q]` quit
- `english_popup.sh` — Legacy standalone English improvement popup (predates tool_launcher)
- `plugins/` — Managed by TPM (Tmux Plugin Manager). Includes `tmux-sensible` and `tmux-ssh-split`.

## Adding a New Tool

1. Create script in `tools/` using existing tools as template
2. Add entry to `TOOLS` array in `tool_launcher.sh`
3. If needed, add OpenAI function to `~/.bash_functions/openai_functions.sh`
4. Make script executable

## Key Conventions

- **Portable regex**: Use `[[:space:]]` instead of `\s` (BSD/macOS compatible)
- **Clipboard**: Must support all platforms — `pbcopy` (macOS), `wl-copy` (Wayland), `xclip`/`xsel` (X11)
- **Terminal cleanup**: Always trap `stty sane` on EXIT to restore terminal state
- **Raw input**: Use `stty raw -echo` for character-by-character input; handle backspace (`0x7f`/`0x08`) and ESC sequences manually

## Dependencies

`tmux`, `bash`, `fzf`, `jq`, `curl`, clipboard tool, `OPENAI_API_KEY` env var.

## TPM (Plugin Manager)

- `prefix + I` — Install plugins
- `prefix + U` — Update plugins
- `prefix + alt + u` — Uninstall plugins
- TPM tests: `plugins/tpm/tests/` (vagrant-based)
