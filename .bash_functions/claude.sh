cl(){
    local ext=""
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--danger)
                ext="$ext --dangerously-skip-permissions"
                shift
                ;;
            -r|--resume)
                [[ -z "$2" ]] && { echo "Error: --resume requires a value" >&2; return 1; }
                ext="$ext --resume $2"
                shift 2
                ;;
            -c|--continue)
                ext="$ext --continue"
                shift
                ;;
            -m|--model)
                [[ -z "$2" ]] && { echo "Error: --model requires a value" >&2; return 1; }
                ext="$ext --model $2"
                shift 2
                ;;
            -p|--print)
                ext="$ext --print"
                shift
                ;;
            -e|--effort)
                [[ -z "$2" ]] && { echo "Error: --effort requires a value" >&2; return 1; }
                ext="$ext --effort $2"
                shift 2
                ;;
            --perm|--permission-mode)
                [[ -z "$2" ]] && { echo "Error: --permission-mode requires a value" >&2; return 1; }
                ext="$ext --permission-mode $2"
                shift 2
                ;;
            --budget)
                [[ -z "$2" ]] && { echo "Error: --budget requires a value" >&2; return 1; }
                ext="$ext --max-budget-usd $2"
                shift 2
                ;;
            --debug)
                if [[ -n "$2" && "$2" != -* ]]; then
                    ext="$ext --debug $2"
                    shift 2
                else
                    ext="$ext --debug"
                    shift
                fi
                ;;
            --json)
                ext="$ext --output-format json"
                shift
                ;;
            --bare)
                ext="$ext --bare"
                shift
                ;;
            -h|--help)
                cat <<'EOF'
Usage: cl [options] [prompt]

Session:
  -c, --continue            Continue most recent session
  -r, --resume <id>         Resume session by ID (or open picker)

Model:
  -m, --model <model>       Model alias: sonnet | opus | haiku | or full name
  -e, --effort <level>      Effort: low | medium | high | xhigh | max
      --budget <usd>        Max spend in USD (--print mode only)

Mode:
  -p, --print [prompt]      Non-interactive: print response and exit
      --json                Output as JSON (with --print)
      --perm <mode>         Permission mode:
                              acceptEdits | auto | bypassPermissions |
                              default | dontAsk | plan
  -d, --danger              --dangerously-skip-permissions (sandbox only)
      --bare                Minimal mode: skip hooks, LSP, plugins, memory

Debug:
      --debug [filter]      Enable debug (optional filter, e.g. "api,hooks")

  -h, --help                Show this help

Examples:
  cl                        Start interactive session
  cl -c                     Continue last session
  cl -m opus                Start with Opus model
  cl -p "summarize this"    One-shot print mode
  cl -p --json "list deps"  Print as JSON
  cl -d                     Skip all permission prompts
  cl -e low -p "quick task" Low-effort one-shot
EOF
                return 0
                ;;
            --)
                shift
                args+=("$@")
                break
                ;;
            -*)
                echo "Unknown option: $1" >&2
                echo "Use -h for usage information" >&2
                return 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    echo "claude${ext}${args:+ ${args[*]}}"
    claude $ext "${args[@]}"
}
