#!/usr/bin/env bash
#
# set -e
#
# TMP_IN=$(mktemp)
# TMP_OUT=$(mktemp)
#
# cleanup() {
#   rm -f "$TMP_IN" "$TMP_OUT"
# }
# trap cleanup EXIT
#
# echo "Paste your text below."
# echo "(Finish with Ctrl+D)"
# echo "---------------------"
#
# cat > "$TMP_IN"
#
# echo
# echo "Press:"
# echo "  r  → Rewrite English"
# echo "  c  → Copy output"
# echo "  q  → Quit"
# echo
#
# while true; do
#   read -n1 -s key
#   case "$key" in
#     r)
#       clear
#       echo "Rewriting..."
#       echo "---------------------"
#       open_ai_improve_english < "$TMP_IN" | tee "$TMP_OUT"
#       echo
#       echo "[r] rewrite again | [c] copy | [q] quit"
#       ;;
#     c)
#       if command -v pbcopy >/dev/null; then
#         pbcopy < "$TMP_OUT"
#       elif command -v wl-copy >/dev/null; then
#         wl-copy < "$TMP_OUT"
#       else
#         xclip -selection clipboard < "$TMP_OUT"
#       fi
#       echo
#       echo "✔ Copied to clipboard"
#       ;;
#     q)
#       exit 0
#       ;;
#   esac
# done
