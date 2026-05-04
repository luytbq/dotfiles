#!/usr/bin/env bash

# Source bash functions (needed for tmux popup context)
for f in ~/.bash_functions/*.sh; do
    [[ -r "$f" ]] && source "$f"
done

TMP_IN=$(mktemp)
TMP_OUT=$(mktemp)
TMP_ERR=$(mktemp)
trap 'stty sane </dev/tty; rm -f "$TMP_IN" "$TMP_OUT" "$TMP_ERR"' EXIT

clear
echo "=== Translate: English → Vietnamese ==="
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
echo "Translating..."

if ! open_ai_translate_en_vi < "$TMP_IN" > "$TMP_OUT" 2> "$TMP_ERR"; then
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

while true; do
    clear
    echo "===== Vietnamese Translation ====="
    echo
    cat "$TMP_OUT"
    echo
    echo "────────────────────────────"
    echo "[y] Copy to clipboard   [q] Quit"
    read -rsn1 key </dev/tty
    case "$key" in
        y)
            copied=false
            # macOS
            if [[ "$(uname)" == "Darwin" ]]; then
                if [[ -n "$TMUX" ]]; then
                    # Inside tmux: use tmux's buffer and pipe to pbcopy
                    tmux load-buffer "$TMP_OUT" && tmux save-buffer - | pbcopy && copied=true
                elif command -v pbcopy >/dev/null; then
                    pbcopy < "$TMP_OUT" && copied=true
                fi
            # Linux with Wayland
            elif command -v wl-copy >/dev/null && [[ -n "$WAYLAND_DISPLAY" ]]; then
                wl-copy < "$TMP_OUT" && copied=true
            # Linux with X11
            elif command -v xclip >/dev/null && [[ -n "$DISPLAY" ]]; then
                xclip -selection clipboard < "$TMP_OUT" && copied=true
            elif command -v xsel >/dev/null && [[ -n "$DISPLAY" ]]; then
                xsel --clipboard --input < "$TMP_OUT" && copied=true
            fi
            if $copied; then
                echo "Copied! Press any key."
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
