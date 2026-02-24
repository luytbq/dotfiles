#!/usr/bin/env bash

# =============================================================================
# TMUX TOOL LAUNCHER
# =============================================================================
#
# A popup-based tool launcher for tmux that uses fzf to select and run tools.
#
# USAGE:
#   Triggered via tmux keybinding: prefix + e
#   (configured in ~/.tmux.conf)
#
# HOW IT WORKS:
#   1. Press prefix + e to open the launcher popup
#   2. Use fzf to search/select a tool from the list
#   3. The selected tool runs in the popup
#   4. Each tool typically:
#      - Accepts text input (paste text, then Ctrl-S to submit)
#      - Processes the text via OpenAI API
#      - Displays results with option to copy to clipboard
#
# ADDING NEW TOOLS:
#   1. Create a new script in ~/.tmux/tools/
#      - Use existing tools as templates
#      - Script should handle input, processing, and output display
#      - Remember to source ~/.bash_functions/*.sh if using OpenAI functions
#
#   2. Add an entry to the TOOLS array below:
#      TOOLS=(
#          ...
#          "Tool Display Name|script_filename.sh"
#      )
#
#   3. If the tool needs a new OpenAI function, add it to:
#      ~/.bash_functions/openai_functions.sh
#
#   4. Make the script executable:
#      chmod +x ~/.tmux/tools/your_tool.sh
#
# TOOL SCRIPT TEMPLATE:
#   See ~/.tmux/tools/improve_english.sh for a complete example.
#   Key components:
#   - Source bash functions for OpenAI access
#   - Create temp files with cleanup trap
#   - Raw terminal input with Ctrl-S to submit
#   - Display results with [y] copy / [q] quit options
#
# DEPENDENCIES:
#   - fzf: for tool selection
#   - jq: for JSON handling in OpenAI functions
#   - curl: for API calls
#   - wl-copy/xclip/pbcopy: for clipboard support
#   - OPENAI_API_KEY: environment variable for API access
#
# FILES:
#   ~/.tmux/tool_launcher.sh     - This launcher script
#   ~/.tmux/tools/               - Directory containing tool scripts
#   ~/.bash_functions/           - OpenAI and other bash functions
#   ~/.tmux.conf                 - Tmux config with keybinding
#
# =============================================================================

TOOLS_DIR="$HOME/.tmux/tools"

# Define tools: "Display Name|script_name.sh"
# Add new tools here following the same format
TOOLS=(
    "Improve English|improve_english.sh"
    "Summarize Text|summarize_text.sh"
    "Translate: Vietnamese → English|translate_vi_to_en.sh"
    "Translate: English → Vietnamese|translate_en_to_vi.sh"
    "Quick Search|quick_search.sh"
)

# Build the list for fzf
tool_list=""
for tool in "${TOOLS[@]}"; do
    name="${tool%%|*}"
    tool_list+="$name"$'\n'
done

# Remove trailing newline
tool_list="${tool_list%$'\n'}"

# Show fzf selector
selected=$(echo "$tool_list" | fzf --prompt="Select tool: " --height=40% --reverse --border)

# Exit if nothing selected
[[ -z "$selected" ]] && exit 0

# Find the script for the selected tool
for tool in "${TOOLS[@]}"; do
    name="${tool%%|*}"
    script="${tool##*|}"
    if [[ "$name" == "$selected" ]]; then
        exec "$TOOLS_DIR/$script"
    fi
done
