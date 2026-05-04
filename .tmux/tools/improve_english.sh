#!/usr/bin/env bash

# Source bash functions (needed for tmux popup context)
for f in ~/.bash_functions/*.sh; do
    [[ -r "$f" ]] && source "$f"
done

TMP_IN=$(mktemp)
TMP_OUT=$(mktemp)
TMP_ERR=$(mktemp)
TMP_IMPROVED=$(mktemp)
trap 'stty sane </dev/tty; rm -f "$TMP_IN" "$TMP_OUT" "$TMP_ERR" "$TMP_IMPROVED"' EXIT

clear
echo "=== Improve English ==="
echo "Paste text. Press Ctrl-S to submit."
echo "────────────────────────────"
echo

# Raw mode so we can catch function keys
stty raw -echo </dev/tty

while true; do
    IFS= read -r -n1 ch </dev/tty

    # Ctrl-S = ASCII 19 (0x13)
    if [[ $ch == $'\x13' ]]; then
        break
    fi

    # Handle backspace (0x7f or 0x08)
    if [[ $ch == $'\x7f' || $ch == $'\x08' ]]; then
        # Remove last character from temp file if not empty
        if [[ -s "$TMP_IN" ]]; then
            # Truncate last byte from file
            truncate -s -1 "$TMP_IN" 2>/dev/null || \
                sed -i '$ s/.$//' "$TMP_IN"
            # Move cursor back, overwrite with space, move back again
            printf '\b \b'
        fi
        continue
    fi

    # Handle ESC sequences (arrow keys, etc.) - pass through
    if [[ $ch == $'\e' ]]; then
        read -r -n2 rest </dev/tty
        printf "%s%s" "$ch" "$rest" >> "$TMP_IN"
        printf "%s%s" "$ch" "$rest"
        continue
    fi

    printf "%s" "$ch"
    printf "%s" "$ch" >> "$TMP_IN"
done

stty sane </dev/tty

if [[ ! -s "$TMP_IN" ]]; then
    echo
    echo "No input. Press any key."
    read -r </dev/tty
    exit 0
fi

echo
echo "Processing..."

if ! open_ai_improve_english < "$TMP_IN" > "$TMP_OUT" 2> "$TMP_ERR"; then
    clear
    echo "=== API Error ==="
    echo "────────────────────────────"
    cat "$TMP_ERR"
    echo
    echo "────────────────────────────"
    echo "Press any key to exit."
    read -rsn1 </dev/tty
    exit 1
fi

# Extract the improved text (everything after "IMPROVED:" until end or next section)
# Use awk to get only lines between IMPROVED: and the end, skipping the header
awk '/^IMPROVED:/{found=1; next} found{print}' "$TMP_OUT" | sed '/^$/d' > "$TMP_IMPROVED"

# Extract scores (macOS compatible - no grep -P)
score_grammar=$(sed -n 's/^Grammar:[[:space:]]*\([0-9]*\).*/\1/p' "$TMP_OUT" | head -1)
score_vocab=$(sed -n 's/^Vocabulary:[[:space:]]*\([0-9]*\).*/\1/p' "$TMP_OUT" | head -1)
score_style=$(sed -n 's/^Style:[[:space:]]*\([0-9]*\).*/\1/p' "$TMP_OUT" | head -1)
score_overall=$(sed -n 's/^Overall:[[:space:]]*\([0-9]*\).*/\1/p' "$TMP_OUT" | head -1)
# Default to "?" if empty
[[ -z "$score_grammar" ]] && score_grammar="?"
[[ -z "$score_vocab" ]] && score_vocab="?"
[[ -z "$score_style" ]] && score_style="?"
[[ -z "$score_overall" ]] && score_overall="?"

# Function to get score bar
get_score_bar() {
    local score=$1
    local width=20
    if [[ "$score" == "?" ]]; then
        printf '[%s]' "$(printf '?%.0s' $(seq 1 $width))"
        return
    fi
    local filled=$((score * width / 100))
    local empty=$((width - filled))
    printf '[%s%s]' "$(printf '█%.0s' $(seq 1 $filled) 2>/dev/null)" "$(printf '░%.0s' $(seq 1 $empty) 2>/dev/null)"
}

while true; do
    clear
    
    # Display scores at the top
    echo "SCORES"
    echo "────────────────────────────────────────"
    printf "  Grammar:    %3s  %s\n" "$score_grammar" "$(get_score_bar "$score_grammar")"
    printf "  Vocabulary: %3s  %s\n" "$score_vocab" "$(get_score_bar "$score_vocab")"
    printf "  Style:      %3s  %s\n" "$score_style" "$(get_score_bar "$score_style")"
    echo "────────────────────────────────────────"
    printf "  Overall:    %3s  %s\n" "$score_overall" "$(get_score_bar "$score_overall")"
    echo
    
    # Display the rest of the output (issues and improved text)
    # Skip the SCORES section, show from GRAMMAR ISSUES onwards
    sed -n '/^GRAMMAR ISSUES:/,$p' "$TMP_OUT"
    
    echo
    echo "────────────────────────────"
    echo "[y] Copy improved text   [q] Quit"
    read -rsn1 key </dev/tty
    case "$key" in
        y)
            copied=false
            # macOS
            if [[ "$(uname)" == "Darwin" ]]; then
                if [[ -n "$TMUX" ]]; then
                    # Inside tmux: use tmux's buffer and pipe to pbcopy
                    tmux load-buffer "$TMP_IMPROVED" && tmux save-buffer - | pbcopy && copied=true
                elif command -v pbcopy >/dev/null; then
                    pbcopy < "$TMP_IMPROVED" && copied=true
                fi
            # Linux with Wayland
            elif command -v wl-copy >/dev/null && [[ -n "$WAYLAND_DISPLAY" ]]; then
                wl-copy < "$TMP_IMPROVED" && copied=true
            # Linux with X11
            elif command -v xclip >/dev/null && [[ -n "$DISPLAY" ]]; then
                xclip -selection clipboard < "$TMP_IMPROVED" && copied=true
            elif command -v xsel >/dev/null && [[ -n "$DISPLAY" ]]; then
                xsel --clipboard --input < "$TMP_IMPROVED" && copied=true
            fi
            if $copied; then
                echo "Improved text copied! Press any key."
            else
                echo "Failed to copy (no clipboard tool available). Press any key."
            fi
            read -rsn1 </dev/tty
            ;;
        q)
            break
            ;;
    esac
done
