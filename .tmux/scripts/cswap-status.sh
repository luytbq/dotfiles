#!/usr/bin/env bash
# Prints the active cswap account and its 5h/7d usage for tmux status-right.
# tmux redraws every status-interval seconds, so the result is cached to keep
# cswap (which may hit the usage API) to at most one run per CACHE_TTL.

CACHE_TTL=60
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux"
CACHE_FILE="$CACHE_DIR/cswap-status"
LOCK_FILE="$CACHE_DIR/cswap-status.lock"
NO_INFO="cswap no info"

# tmux runs #() with the server environment, which may lack ~/.local/bin.
PATH="$HOME/.local/bin:$PATH"

mkdir -p "$CACHE_DIR"

cache_fresh() {
    [[ -s "$CACHE_FILE" ]] || return 1
    local mtime
    # GNU stat first, BSD/macOS stat as fallback
    mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null) || return 1
    (( $(date +%s) - mtime < CACHE_TTL ))
}

render() {
    # tmux's default status bar is green, so warning levels change the
    # background instead of the foreground to stay readable.
    jq -r '
        def pct_style(p):
            if p >= 90 then "#[bg=red,fg=white]"
            elif p >= 70 then "#[bg=yellow,fg=black]"
            else "" end;
        def window(tag; w):
            if w == null then "\(tag) ?"
            else (w.pct | floor) as $p
                | "\(pct_style($p))\(tag) \($p)%#[default] \(w.clock)"
            end;

        (.accounts | length) as $total
        | (.accounts[] | select(.active)) as $a
        | ($a.alias // ($a.email | split("@")[0])) as $name
        | (if $total > 1 then "\($a.number)/\($total) " else "" end)
          + $name
          + " | " + window("5h"; $a.usage.fiveHour)
          + " | " + window("7d"; $a.usage.sevenDay)
    '
}

refresh() {
    local json line
    local -a run=()
    # timeout is absent on macOS without coreutils
    command -v timeout >/dev/null && run=(timeout 10)
    if json=$("${run[@]}" cswap list --json 2>/dev/null) \
        && line=$(render <<<"$json" 2>/dev/null) \
        && [[ -n "$line" ]]; then
        printf '%s\n' "$line"
    else
        printf '%s\n' "$NO_INFO"
    fi
}

if ! cache_fresh; then
    # Several tmux clients can trigger this at once; only one refreshes.
    # Without flock (macOS) a duplicate refresh is harmless, just wasted.
    locked=1
    if command -v flock >/dev/null; then
        exec 9>"$LOCK_FILE"
        flock -n 9 || locked=0
    fi
    if (( locked )) && ! cache_fresh; then
        refresh >"$CACHE_FILE.$$" && mv "$CACHE_FILE.$$" "$CACHE_FILE"
    fi
fi

cat "$CACHE_FILE" 2>/dev/null || echo "$NO_INFO"
