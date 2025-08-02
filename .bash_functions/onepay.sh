#!/bin/bash

# Utility function to normalize paths (handle trailing slashes consistently)
normalize_path() {
    local path="$1"
    local add_trailing="${2:-false}"
 
    # Handle empty path
    [[ -z "$path" ]] && return 0

    # Remove trailing slash
    path="${path%/}"


    if [[ "$add_trailing" == "true" ]]; then
        path="${path}/"
    fi

    echo "$path"
}

# Run rsync with standard parameters and error handling
run_rsync() {
    local src="$1"
    local dest="$2"
    local port="$3"
    local user="$4"
    echo "Syncing $src to $dest" >&2
    rsync -av --progress --delete -e "ssh -p $port" "$src" "$user@$dest"
    local rsync_exit_code=$?
    if [[ $rsync_exit_code -ne 0 ]]; then
        echo "Error syncing $src to $dest (exit code $rsync_exit_code)" >&2
        return $rsync_exit_code
    fi
}

# Run SSH command with error handling
run_ssh_command() {
    local host="$1"
    local port="$2"
    local user="$3"
    local cmd="$4"
    echo "Executing command on $user@$host:$port: $cmd" >&2
    ssh -p "$port" "$user@$host" "$cmd"
    local ssh_exit_code=$?
    if [[ $ssh_exit_code -ne 0 ]]; then
        echo "Error executing SSH command (exit code $ssh_exit_code)" >&2
        return $ssh_exit_code
    fi
}

# Check for required dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing[*]}" >&2
        return 1
    fi
}

# Show help for different functions
show_help() {
    local function_name="$1"
    case "$function_name" in
        "create_mr")
            cat << 'EOF'
Usage: create_mr [OPTIONS]
Create a merge request URL and open it in browser

Options:
  --source-dir, -sd    Source branch (default: current branch)
  --target            Target branch (default: prod)
  --title             MR title
  --description       MR description
  --help              Show this help message

Example:
  create_mr --target main --title "Fix bug" --description "Fixed critical bug"
EOF
            ;;
        "sync_theme")
            cat << 'EOF'
Usage: sync_theme [OPTIONS]
Sync theme files to remote server

Options:
  --user, -u          SSH user (default: root)
  --host, -h          SSH host (required)
  --port, -p          SSH port (default: 7602)
  --theme             Theme name (auto-detected from repo if not specified)
  --help              Show this help message

Example:
  sync_theme --host dev18 --user myuser --theme my-theme
EOF
            ;;
        "build_theme_and_sync")
            cat << 'EOF'
Usage: build_theme_and_sync [OPTIONS]
Build Angular theme and sync to remote server

Options:
  --user, -u          SSH user (default: root)
  --host, -h          SSH host (required)
  --port, -p          SSH port (default: 7602)
  --theme             Theme name (auto-detected from repo if not specified)
  --help              Show this help message

Example:
  build_theme_and_sync --host dev18 --user myuser
EOF
            ;;
        "ssh_execute_command")
            cat << 'EOF'
Usage: ssh_execute_command [OPTIONS]
Execute command on remote server via SSH

Options:
  --user, -u          SSH user (default: root)
  --host, -h          SSH host (required)
  --port, -p          SSH port (default: 7602)
  --command, -cmd     Command to execute (required)
  --help              Show this help message

Example:
  ssh_execute_command --host dev18 --command "systemctl status nginx"
EOF
            ;;
        "ssh_fzf_sync")
            cat << 'EOF'
Usage: ssh_fzf_sync [OPTIONS]
Sync selected files to remote server using fzf

Options:
  --user, -u          SSH user (default: root)
  --host, -h          SSH host (required)
  --port, -p          SSH port (default: 7602)
  --source-dir, -sd   Local source directory (required)
  --remote-dir, -rd   Remote destination directory (required)
  --help              Show this help message

Example:
  ssh_fzf_sync --host dev18 --source-dir ./src --remote-dir /var/www/html
EOF
            ;;
        "replace_dev_domain")
            cat << 'EOF'
Usage: replace_dev_domain <subdomain>
Replace domain in TypeScript files

Arguments:
  subdomain           Target subdomain (e.g., dev18)

Options:
  --help              Show this help message

Example:
  replace_dev_domain dev18
EOF
            ;;
        "watch_angular")
            cat << 'EOF'
Usage: watch_angular [OPTIONS]
Build Angular project with watch mode

Options:
  --help              Show this help message

Note: Must be run from a paygate theme repository
EOF
            ;;
        "ssh_fzf_sync_and_execute")
            cat << 'EOF'
Usage: ssh_fzf_sync_and_execute [OPTIONS]
Sync files and execute command on remote server via SSH
Options:
  --user, -u          SSH user (default: root)
  --host, -h          SSH host (required)
  --port, -p          SSH port (default: 7602)
  --source-dir, -sd   Local source directory (required)
  --remote-dir, -rd   Remote destination directory (required)
  --command, -cmd     Command to execute after sync (required)
  --help              Show this help message
Example:
  ssh_fzf_sync_and_execute --host dev18 --source-dir ./src --remote-dir /var/www/html --command "systemctl restart nginx"
EOF
            ;;
        *)
            cat << 'EOF'
Available functions:
  create_mr              - Create merge request URL
  sync_theme            - Sync theme to remote server
  build_theme_and_sync  - Build and sync theme
  ssh_execute_command   - Execute SSH command
  ssh_fzf_sync         - Sync files with fzf selection
  ssh_fzf_sync_and_execute - Sync files and execute command
  replace_dev_domain   - Replace domain in files
  watch_angular        - Build with watch mode
  pipelines_check      - Open CI/CD pipelines in browser

Use <function_name> --help for detailed usage information.
EOF
            ;;
    esac
}

# Parse SSH-related arguments and store them in an associative array
parse_args() {
    # Store results in associative array
    declare -n result=$1
    local function_name="$2"
    shift 2

    # Initialize defaults
    result[user]="root"
    result[port]="7602"
    result[host]=""
    result[source_dir]=""
    result[remote_dir]=""
    result[remote_cmd]=""
    result[theme]=""
    result[target]=""
    result[title]=""
    result[description]=""
    result[help]="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                result[help]="true"
                shift
                break  # Immediately stop parsing if --help is found
                ;;
            --user|-u)
                [[ -z "$2" ]] && { echo "Error: --user requires a value" >&2; return 1; }
                result[user]="$2"
                shift 2
                ;;
            --host|-h)
                [[ -z "$2" ]] && { echo "Error: --host requires a value" >&2; return 1; }
                result[host]="$2"
                shift 2
                ;;
            --port|-p)
                [[ -z "$2" ]] && { echo "Error: --port requires a value" >&2; return 1; }
                result[port]="$2"
                shift 2
                ;;
            --source-dir|-sd)
                [[ -z "$2" ]] && { echo "Error: --source-dir requires a value" >&2; return 1; }
                result[source_dir]="$(normalize_path "$2")"
                shift 2
                ;;
            --remote-dir|-rd)
                [[ -z "$2" ]] && { echo "Error: --remote-dir requires a value" >&2; return 1; }
                result[remote_dir]="$(normalize_path "$2")"
                shift 2
                ;;
            --command|-cmd)
                [[ -z "$2" ]] && { echo "Error: --command requires a value" >&2; return 1; }
                result[remote_cmd]="$2"
                shift 2
                ;;
            --theme)
                [[ -z "$2" ]] && { echo "Error: --theme requires a value" >&2; return 1; }
                result[theme]="$2"
                shift 2
                ;;
            --target)
                [[ -z "$2" ]] && { echo "Error: --target requires a value" >&2; return 1; }
                result[target]="$2"
                shift 2
                ;;
            --title)
                [[ -z "$2" ]] && { echo "Error: --title requires a value" >&2; return 1; }
                result[title]="$2"
                shift 2
                ;;
            --description)
                [[ -z "$2" ]] && { echo "Error: --description requires a value" >&2; return 1; }
                result[description]="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
        esac
    done

    # Show help if requested
    if [[ "${result[help]}" == "true" ]]; then
        show_help "$function_name"
        return 2  # Special return code for help
    fi
}

# Get the repository's remote origin URL
get_repo_url() {
    git remote get-url origin 2>/dev/null || { echo "Error: Not a git repository or no origin set" >&2; return 1; }
}

# Convert SSH repo URL to HTTPS
get_repo_url_http() {
    local repo_url
    repo_url=$(get_repo_url) || return 1
    echo "$repo_url" | sed -E 's#ssh://git@([^:]+):[0-9]+/(.+)(\.git)?$#https://\1/\2#' | sed 's/\.git$//'
}

# Extract repository group from URL
get_repo_group() {
    local repo_url
    repo_url=$(get_repo_url) || return 1
    echo "$repo_url" | sed -E 's#.*onepay/([^/]+)/.*#\1#'
}

# Extract repository name from URL
get_repo_name() {
    local repo_url
    repo_url=$(get_repo_url) || return 1
    echo "$repo_url" | sed -E 's#.*/([^/]+)\.git$#\1#'
}

# Get theme name for paygate repositories
get_theme_name() {
    local repo_group
    repo_group=$(get_repo_group) || return 1
    if [[ "$repo_group" != "paygate" ]]; then
        echo "Error: CWD is not a paygate theme repository" >&2
        return 1
    fi

    local repo_name
    repo_name=$(get_repo_name) || return 1
    if [[ "$repo_name" == "paygate-general-fee" ]]; then
        repo_name=$(basename "$PWD")
    fi

    echo "$repo_name" | sed -E 's#^paygate-(.*)$#\1#'
}

# Create a merge request URL
create_mr() {
    local args
    declare -A args
    parse_args args "create_mr" "$@"
    local parse_result=$?
    
    # Handle help request
    [[ $parse_result -eq 2 ]] && return 0
    [[ $parse_result -ne 0 ]] && return $parse_result

    local source="${args[source_dir]:-$(git branch --show-current 2>/dev/null)}"
    local target="${args[target]:-prod}"
    local title="${args[title]}"
    local description="${args[description]}"

    if [[ -z "$source" ]]; then
        echo "Error: No source branch specified and no current branch detected" >&2
        return 1
    fi

    local repo_url
    repo_url=$(get_repo_url_http) || return 1

    # URL encode title and description if they contain special characters
    if [[ -n "$title" ]]; then
        title=$(printf '%s' "$title" | sed 's/ /%20/g; s/&/%26/g; s/#/%23/g')
    fi
    if [[ -n "$description" ]]; then
        description=$(printf '%s' "$description" | sed 's/ /%20/g; s/&/%26/g; s/#/%23/g')
    fi

    local mr_url="${repo_url}/-/merge_requests/new"
    mr_url="${mr_url}?merge_request[source_branch]=${source}"
    mr_url="${mr_url}&merge_request[target_branch]=${target}"
    [[ -n "$title" ]] && mr_url="${mr_url}&merge_request[title]=${title}"
    [[ -n "$description" ]] && mr_url="${mr_url}&merge_request[description]=${description}"

    open_url "$mr_url"
}

# Check CI/CD pipelines in browser
pipelines_check() {
    if [[ "$1" == "--help" ]]; then
        show_help "pipelines_check"
        return 0
    fi
    local repo_url
    repo_url=$(get_repo_url_http) || return 1
    local url="${repo_url}/-/pipelines"
    open_url "$url"
}

open_url() {
    if [[ "$1" == "--help" ]]; then
        echo "Usage: open_url <url>\nOpen the specified URL in the browser using the first available command (open, xdg-open, or start)." >&2
        return 0
    fi
    local url=$1
    echo "Opening URL: $url" >&2
    if command -v open >/dev/null; then
        open "$url"
    elif command -v xdg-open >/dev/null; then
        xdg-open "$url"
    elif command -v start >/dev/null; then
        start "$url"
    else
        echo "Error: No supported command to open a browser (open, xdg-open, start)" >&2
        return 1
    fi
}

# Replace domain in TypeScript files
replace_dev_domain() {
    # Handle --help flag
    if [[ "$1" == "--help" ]]; then
        show_help "replace_dev_domain"
        return 0
    fi

    local subdomain="$1"
    if [[ -z "$subdomain" ]]; then
        echo "Usage: replace_dev_domain <subdomain> (e.g., replace_dev_domain dev18)" >&2
        return 1
    fi

    find . -type f -name "*.ts" \
        -not -path "./node_modules/*" \
        -not -path "./dist/*" \
        -not -path "./.git/*" \
        -not -name "lang-vi.ts" \
        -not -name "lang-en.ts" \
        -exec grep -lE 'https://(.*)onepay.vn' {} + \
        | xargs -r sed -i "s|https://\(.*\)onepay.vn|https://${subdomain}.onepay.vn|g"
}

# Replace domain in ./dist/ files
replace_dev_domain_dist() {
    if [[ "$1" == "--help" ]]; then
        echo "Usage: replace_dev_domain_dist <subdomain>\nReplace domain in files under ./dist/\n\nArguments:\n  subdomain  Target subdomain (e.g., dev18)\n\nExample:\n  replace_dev_domain_dist dev18" >&2
        return 0
    fi
    local subdomain="$1"
    if [[ -z "$subdomain" ]]; then
        echo "Usage: replace_dev_domain_dist <subdomain> (e.g., replace_dev_domain_dist dev18)" >&2
        return 1
    fi
    find ./dist/ -type f \
        -exec grep -lE 'https://(.*)onepay.vn' {} + \
        | xargs -r sed -i "s|https://\(.*\)onepay.vn|https://${subdomain}.onepay.vn|g"
}

# Build Angular project with watch mode
watch_angular() {
    # Handle --help flag
    if [[ "$1" == "--help" ]]; then
        show_help "watch_angular"
        return 0
    fi

    local repo_group
    repo_group=$(get_repo_group) || return 1
    if [[ "$repo_group" != "paygate" ]]; then
        echo "Error: Only paygate/paygate-* repositories are supported" >&2
        return 1
    fi

    local theme
    theme=$(get_theme_name) || return 1

    echo "Cleaning dist/..." >&2
    rm -rf dist/

    check_dependencies "nvm" "ng" || return 1

    nvm use 16 || { echo "Error: Failed to switch to Node.js v16" >&2; return 1; }

    local cmd="ng build --configuration production --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/ --watch --optimization=false --build-optimizer=false"
    echo "Running command: $cmd" >&2
    eval "$cmd"
}

# Sync theme files to remote server
sync_theme() {
    local args
    declare -A args
    parse_args args "sync_theme" "$@"
    local parse_result=$?
    # Explicitly handle --help request
    if [[ "${args[help]}" == "true" ]]; then
        show_help "sync_theme"
        return 0
    fi
    [[ $parse_result -ne 0 ]] && return $parse_result

    # Validate required arguments
    if [[ -z "${args[host]}" ]]; then
        echo "Error: --host/-h is required" >&2
        return 1
    fi

    if [[ "${args[host]}" == "dev18" ]]; then
		sync_theme_dev18 --user "${args[user]}" --host "${args[host]}" --theme "${args[theme]}" --port "${args[port]}"
        return $?
    fi

    local theme="${args[theme]:-$(get_theme_name)}"
    if [[ -z "$theme" ]]; then
        echo "Error: --theme required or must be in a paygate theme repository" >&2
        return 1
    fi

    local source_dir="$(normalize_path "dist/paygate/${theme}" true)"
    local remote_dir="$(normalize_path "/usr/share/nginx/onepay.vn/paygate/${theme}" true)"
    echo "Syncing theme to ${args[user]}@${args[host]}:${remote_dir}" >&2
    run_rsync "${source_dir}" "${args[host]}:${remote_dir}" "${args[port]}" "${args[user]}"
    return $?
}

sync_theme_dev18() {
    local args
    declare -A args
    parse_args args "sync_theme_dev18" "$@"
    # Explicitly handle --help request
    if [[ "${args[help]}" == "true" ]]; then
        show_help "sync_theme_dev18"
        return 0
    fi

    local theme="${args[theme]:-$(get_theme_name)}"
    if [[ -z "$theme" ]]; then
        echo "Error: --theme required or must be in a paygate theme repository" >&2
        return 1
    fi

    local rsync_remote_dir="/home/${args[user]}/${theme}/"
    echo "Syncing theme to ${args[user]}@dev18:${rsync_remote_dir}" >&2
    run_rsync "dist/paygate/${theme}/" "dev18:${rsync_remote_dir}" "${args[port]}" "${args[user]}"

    local target_remote_dir="/usr/share/nginx/onepay.vn/paygate/${theme}"
    run_ssh_command "${args[host]}" "${args[port]}" "${args[user]}" "sudo rm -rf \"$target_remote_dir\" && sudo cp -r \"$rsync_remote_dir\" \"$target_remote_dir\""
    return $?
}

# Build theme and sync to remote server
build_theme_and_sync() {
    local args
    declare -A args
    parse_args args "build_theme_and_sync" "$@"
    # Explicitly handle --help request
    if [[ "${args[help]}" == "true" ]]; then
        show_help "build_theme_and_sync"
        return 0
    fi

    # Validate required arguments
    if [[ -z "${args[host]}" ]]; then
        echo "Error: --host/-h is required" >&2
        return 1
    fi

    local theme="${args[theme]:-$(get_theme_name)}"
    if [[ -z "$theme" ]]; then
        echo "Error: --theme required or must be in a paygate theme repository" >&2
        return 1
    fi

    if ! command -v nvm >/dev/null; then
        echo "Error: nvm is required" >&2
        return 1
    fi

    nvm use 16 || { echo "Error: Failed to switch to Node 16" >&2; return 1; }

    replace_dev_domain "${args[host]}" || return 1

    echo "Cleaning dist/..." >&2
    rm -rf dist/

    echo "Building theme..." >&2
    local cmd="ng build --configuration production --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/"
    echo "Running command: $cmd" >&2
    eval "$cmd" || return 1

    sync_theme --user "${args[user]}" --host "${args[host]}" --port "${args[port]}" --theme "$theme"
    return $?
}

# Execute command over SSH
ssh_execute_command() {
    local args
    declare -A args
    parse_args args "ssh_execute_command" "$@"
    # Explicitly handle --help request
    if [[ "${args[help]}" == "true" ]]; then
        show_help "ssh_execute_command"
        return 0
    fi

    # Validate required arguments
    if [[ -z "${args[host]}" ]]; then
        echo "Error: --host/-h is required" >&2
        return 1
    fi
    # Validate required arguments
    if [[ -z "${args[remote_cmd]}" ]]; then
        echo "Error: --command/-cmd is required" >&2
        return 1
    fi

    echo "Executing command on ${args[user]}@${args[host]}:${args[port]}" >&2
    run_ssh_command "${args[host]}" "${args[port]}" "${args[user]}" "${args[remote_cmd]}"
    return $?
}

# Sync files to a remote server using rsync and fzf
ssh_fzf_sync() {
    local args
    declare -A args
    parse_args args "ssh_fzf_sync" "$@"
    local parse_result=$?
    # Explicitly handle --help request
    if [[ "${args[help]}" == "true" ]]; then
        show_help "ssh_fzf_sync"
        return 0
    fi
    [[ $parse_result -ne 0 ]] && return $parse_result

    # Validate required arguments
    if [[ -z "${args[source_dir]}" || -z "${args[host]}" || -z "${args[remote_dir]}" ]]; then
        echo "Error: --source-dir/-sd, --host/-h, and --remote-dir/-rd are required" >&2
        return 1
    fi

    # Check dependencies
    command -v fzf >/dev/null || { echo "Error: fzf is required" >&2; return 1; }
    command -v rsync >/dev/null || { echo "Error: rsync is required" >&2; return 1; }

    # Ensure source_dir exists
    if [[ ! -d "${args[source_dir]}" ]]; then
        echo "Error: ${args[source_dir]} is not a valid directory" >&2
        return 1
    fi

    # Select files with fzf
    selected_files=$(find "${args[source_dir]}" -type f -not -path '*/\.*' | sed "s|^${args[source_dir]}/||" | fzf --multi)

    if [[ -z "$selected_files" ]]; then
        echo "No files selected." >&2
        return 0
    fi

    local exit_code=0
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        src="${args[source_dir]}/${file_path}"
        remote_path="${args[remote_dir]%/}/${file_path#/}"
        dest="${args[host]}:${remote_path}"

        run_rsync "$src" "$dest" "${args[port]}" "${args[user]}"
        rsync_exit_code=$?
        if [[ $rsync_exit_code -ne 0 ]]; then
            exit_code=$rsync_exit_code
        fi
    done <<< "$selected_files"

    return $exit_code
}

# Sync files and execute a command
ssh_fzf_sync_and_execute() {
    local args
    declare -A args
    parse_args args "ssh_fzf_sync_and_execute" "$@"
    local parse_result=$?
    # Explicitly handle --help request
    if [[ "${args[help]}" == "true" ]]; then
        show_help "ssh_fzf_sync_and_execute"
        return 0
    fi
    [[ $parse_result -ne 0 ]] && return $parse_result

    # Validate required arguments
    if [[ -z "${args[source_dir]}" || -z "${args[host]}" || -z "${args[remote_dir]}" || -z "${args[remote_cmd]}" ]]; then
        echo "Error: --source-dir/-sd, --host/-h, --remote-dir/-rd, and --command/-cmd are required" >&2
        return 1
    fi

    # Sync files
    ssh_fzf_sync --source-dir "${args[source_dir]}" --user "${args[user]}" --host "${args[host]}" --port "${args[port]}" --remote-dir "${args[remote_dir]}"
    if [[ $? -ne 0 ]]; then
        echo "Sync failed." >&2
        return 1
    fi

    # Execute command
    ssh_execute_command --user "${args[user]}" --host "${args[host]}" --port "${args[port]}" --command "${args[remote_cmd]}"
    return $?
}
