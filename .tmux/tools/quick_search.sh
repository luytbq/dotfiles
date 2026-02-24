#!/usr/bin/env bash

# Source bash functions (needed for tmux popup context)
for f in ~/.bash_functions/*.sh; do
    [[ -r "$f" ]] && source "$f"
done

TMP_IN=$(mktemp)
TMP_GPT=$(mktemp)
TMP_GOOGLE_JSON=$(mktemp)
TMP_GOOGLE=$(mktemp)
trap 'stty sane </dev/tty; rm -f "$TMP_IN" "$TMP_GPT" "$TMP_GOOGLE_JSON" "$TMP_GOOGLE"' EXIT

copy_to_clipboard() {
    local file="$1"
    local copied=false
    # macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ -n "$TMUX" ]]; then
            tmux load-buffer "$file" && tmux save-buffer - | pbcopy && copied=true
        elif command -v pbcopy >/dev/null; then
            pbcopy < "$file" && copied=true
        fi
    # Linux with Wayland
    elif command -v wl-copy >/dev/null && [[ -n "$WAYLAND_DISPLAY" ]]; then
        wl-copy < "$file" && copied=true
    # Linux with X11
    elif command -v xclip >/dev/null && [[ -n "$DISPLAY" ]]; then
        xclip -selection clipboard < "$file" && copied=true
    elif command -v xsel >/dev/null && [[ -n "$DISPLAY" ]]; then
        xsel --clipboard --input < "$file" && copied=true
    fi
    if $copied; then
        echo "Copied! Press any key."
    else
        echo "Failed to copy (no clipboard tool available). Press any key."
    fi
    read -rsn1 </dev/tty
}

open_url() {
    local url="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        open "$url" 2>/dev/null
    elif command -v xdg-open >/dev/null; then
        xdg-open "$url" 2>/dev/null &
    fi
}

clear
echo "=== Quick Search ==="
echo "Type your question. Press Ctrl-S to submit."
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
        if [[ -s "$TMP_IN" ]]; then
            truncate -s -1 "$TMP_IN" 2>/dev/null || \
                sed -i '$ s/.$//' "$TMP_IN"
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

QUERY=$(cat "$TMP_IN")

echo
echo "Searching..."

# Background job 1: Google search
(
    if command -v googler >/dev/null 2>&1; then
        googler --json -n 8 --noprompt "$QUERY" > "$TMP_GOOGLE_JSON" 2>/dev/null
        if [[ -s "$TMP_GOOGLE_JSON" ]]; then
            result_count=$(jq 'length' "$TMP_GOOGLE_JSON" 2>/dev/null)
            if [[ "$result_count" -gt 0 ]] 2>/dev/null; then
                jq -r 'to_entries[] | "\(.key + 1). \(.value.title)\n   \(.value.url)\n   \(.value.abstract)\n"' "$TMP_GOOGLE_JSON" > "$TMP_GOOGLE"
            else
                echo "(No results from Google)" > "$TMP_GOOGLE"
            fi
        else
            echo "(No results from Google)" > "$TMP_GOOGLE"
        fi
    else
        echo "googler is not installed." > "$TMP_GOOGLE"
        echo "" >> "$TMP_GOOGLE"
        echo "Install it with:" >> "$TMP_GOOGLE"
        echo "  pip install googler" >> "$TMP_GOOGLE"
    fi
) &
PID_GOOGLE=$!

# Spinner while waiting for Google
spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
i=0
while kill -0 "$PID_GOOGLE" 2>/dev/null; do
    printf "\r  %s Searching... " "${spinner[$((i % ${#spinner[@]}))]}"
    sleep 0.1
    ((i++))
done
printf "\r                    \r"

wait "$PID_GOOGLE" 2>/dev/null

# ChatGPT is loaded lazily when user switches to it
GPT_LOADED=false
PID_GPT=""

# Render a scrollable view of a file
# Usage: render_view FILE SCROLL_OFFSET HEADER FOOTER
render_view() {
    local file="$1" offset="$2" header="$3" footer="$4"
    local total_lines avail

    mapfile -t LINES < "$file"
    total_lines=${#LINES[@]}
    # 1 header + 1 blank + 1 separator + 1 footer + 1 scroll indicator = 5 reserved
    avail=$(($(tput lines) - 5))
    [[ $avail -lt 1 ]] && avail=1

    clear
    echo "$header"
    echo

    local end=$((offset + avail))
    [[ $end -gt $total_lines ]] && end=$total_lines

    for ((i=offset; i<end; i++)); do
        printf '%s\n' "${LINES[$i]}"
    done

    echo "────────────────────────────"
    if [[ $total_lines -gt $avail ]]; then
        printf '[line %d-%d of %d]  ' "$((offset + 1))" "$end" "$total_lines"
    fi
    echo "$footer"
}

# Clamp scroll offset to valid range
# Usage: clamp_scroll OFFSET TOTAL_LINES AVAIL
clamp_scroll() {
    local offset="$1" total="$2" avail="$3"
    local max=$((total - avail))
    [[ $max -lt 0 ]] && max=0
    [[ $offset -lt 0 ]] && offset=0
    [[ $offset -gt $max ]] && offset=$max
    echo "$offset"
}

# Display loop
VIEW="google"  # default view
SCROLL_GPT=0
SCROLL_GOOGLE=0

while true; do
    if [[ "$VIEW" == "gpt" ]]; then
        # Show loading state if GPT is still running
        if [[ -n "$PID_GPT" ]] && kill -0 "$PID_GPT" 2>/dev/null; then
            clear
            echo "===== ChatGPT Answer ====="
            echo
            echo "Loading..."
            # Wait with spinner
            while kill -0 "$PID_GPT" 2>/dev/null; do
                printf "\r  %s Loading... " "${spinner[$((i % ${#spinner[@]}))]}"
                sleep 0.1
                ((i++))
            done
            wait "$PID_GPT" 2>/dev/null
            PID_GPT=""
            printf "\r                    \r"
        fi
        render_view "$TMP_GPT" "$SCROLL_GPT" \
            "===== ChatGPT Answer =====" \
            "[j/↓] Down [k/↑] Up [Tab] Google results [y] Copy [q] Quit"
    else
        render_view "$TMP_GOOGLE" "$SCROLL_GOOGLE" \
            "===== Google Results =====" \
            "[j/↓] Down [k/↑] Up [Tab] ChatGPT answer [1-8] Open URL [b] Open in browser [y] Copy [q] Quit"
    fi

    # Read one character in raw mode
    stty raw -echo </dev/tty
    IFS= read -r -n1 key </dev/tty
    stty sane </dev/tty

    # Compute available lines for scroll clamping
    _avail=$(($(tput lines) - 5))
    [[ $_avail -lt 1 ]] && _avail=1

    case "$key" in
        $'\e')
            # Check for arrow key sequence with short timeout
            if IFS= read -r -t 0.05 -n1 bracket </dev/tty && [[ "$bracket" == "[" ]]; then
                IFS= read -r -t 0.05 -n1 arrow </dev/tty
                case "$arrow" in
                    A)  # Up arrow
                        if [[ "$VIEW" == "gpt" ]]; then
                            SCROLL_GPT=$((SCROLL_GPT - 1))
                            mapfile -t _L < "$TMP_GPT"
                            SCROLL_GPT=$(clamp_scroll "$SCROLL_GPT" "${#_L[@]}" "$_avail")
                        else
                            SCROLL_GOOGLE=$((SCROLL_GOOGLE - 1))
                            mapfile -t _L < "$TMP_GOOGLE"
                            SCROLL_GOOGLE=$(clamp_scroll "$SCROLL_GOOGLE" "${#_L[@]}" "$_avail")
                        fi
                        ;;
                    B)  # Down arrow
                        if [[ "$VIEW" == "gpt" ]]; then
                            SCROLL_GPT=$((SCROLL_GPT + 1))
                            mapfile -t _L < "$TMP_GPT"
                            SCROLL_GPT=$(clamp_scroll "$SCROLL_GPT" "${#_L[@]}" "$_avail")
                        else
                            SCROLL_GOOGLE=$((SCROLL_GOOGLE + 1))
                            mapfile -t _L < "$TMP_GOOGLE"
                            SCROLL_GOOGLE=$(clamp_scroll "$SCROLL_GOOGLE" "${#_L[@]}" "$_avail")
                        fi
                        ;;
                esac
            fi
            # Bare ESC: ignore
            ;;
        j)
            if [[ "$VIEW" == "gpt" ]]; then
                SCROLL_GPT=$((SCROLL_GPT + 1))
                mapfile -t _L < "$TMP_GPT"
                SCROLL_GPT=$(clamp_scroll "$SCROLL_GPT" "${#_L[@]}" "$_avail")
            else
                SCROLL_GOOGLE=$((SCROLL_GOOGLE + 1))
                mapfile -t _L < "$TMP_GOOGLE"
                SCROLL_GOOGLE=$(clamp_scroll "$SCROLL_GOOGLE" "${#_L[@]}" "$_avail")
            fi
            ;;
        k)
            if [[ "$VIEW" == "gpt" ]]; then
                SCROLL_GPT=$((SCROLL_GPT - 1))
                mapfile -t _L < "$TMP_GPT"
                SCROLL_GPT=$(clamp_scroll "$SCROLL_GPT" "${#_L[@]}" "$_avail")
            else
                SCROLL_GOOGLE=$((SCROLL_GOOGLE - 1))
                mapfile -t _L < "$TMP_GOOGLE"
                SCROLL_GOOGLE=$(clamp_scroll "$SCROLL_GOOGLE" "${#_L[@]}" "$_avail")
            fi
            ;;
        $'\t')
            if [[ "$VIEW" == "gpt" ]]; then
                VIEW="google"
            else
                VIEW="gpt"
                # Lazy-load ChatGPT on first switch
                if ! $GPT_LOADED; then
                    GPT_LOADED=true
                    echo "$QUERY" | open_ai_ask > "$TMP_GPT" 2>&1 &
                    PID_GPT=$!
                fi
            fi
            ;;
        y)
            if [[ "$VIEW" == "gpt" ]]; then
                copy_to_clipboard "$TMP_GPT"
            else
                copy_to_clipboard "$TMP_GOOGLE"
            fi
            ;;
        [1-8])
            if [[ "$VIEW" == "google" && -s "$TMP_GOOGLE_JSON" ]]; then
                url=$(jq -r ".[$((key - 1))].url // empty" "$TMP_GOOGLE_JSON" 2>/dev/null)
                if [[ -n "$url" ]]; then
                    open_url "$url"
                    echo "Opened: $url"
                    sleep 0.5
                fi
            fi
            ;;
        b)
            if [[ "$VIEW" == "google" ]]; then
                # URL-encode the query and open Google search in browser
                encoded_query=$(printf '%s' "$QUERY" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.stdin.read()))" 2>/dev/null \
                    || printf '%s' "$QUERY" | sed 's/ /+/g')
                open_url "https://www.google.com/search?q=${encoded_query}"
                echo "Opened Google search in browser."
                sleep 0.5
            fi
            ;;
        q)
            break
            ;;
    esac
done
