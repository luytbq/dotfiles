#!/bin/bash

# Parse SSH-related arguments and store them in an associative array
parse_args() {
    # Store results in associative array
    declare -n result=$1
    shift

    # Initialize defaults
    result[user]="root"
    result[port]="7602"
    result[host]=""
    result[source_dir]=""
    result[remote_dir]=""
    result[remote_cmd]=""
    result[theme]=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user|-u)
                result[user]="$2"
                shift 2
                ;;
            --host|-h)
                result[host]="$2"
                shift 2
                ;;
            --port|-p)
                result[port]="$2"
                shift 2
                ;;
            --source-dir|-sd)
                result[source_dir]="$2"
                shift 2
                ;;
            --remote-dir|-rd)
                result[remote_dir]="$2"
                shift 2
                ;;
            --command|-cmd)
                result[remote_cmd]="$2"
                shift 2
                ;;
            --theme)
                result[theme]="$2"
                shift 2
                ;;
			--target)
				result[target]="$2"
				shift 2
				;;
			--title)
				result[title]="$2"
				shift 2
				;;
			--description)
				result[description]="$2"
				shift 2
				;;
			*)
                echo "Unknown argument: $1" >&2
                return 1
                ;;
        esac
    done
}

# Get the repository's remote origin URL
get_repo_url() {
    git remote get-url origin 2>/dev/null || { echo "Error: Not a git repository or no origin set" >&2; return 1; }
}

# Convert SSH repo URL to HTTPS
get_repo_url_http() {
    local repo_url
    repo_url=$(get_repo_url) || return 1
    echo "$repo_url" | sed -E 's#ssh://git@([^:]+):[0-9]+/(.+)\.git#https://\1/\2#'
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
    parse_args args "$@"

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

    local mr_url="${repo_url}/-/merge_requests/new"
    mr_url="${mr_url}?merge_request[source_branch]=${source}"
    mr_url="${mr_url}&merge_request[target_branch]=${target}"
    [[ -n "$title" ]] && mr_url="${mr_url}&merge_request[title]=${title}"
    [[ -n "$description" ]] && mr_url="${mr_url}&merge_request[description]=${description}"

    echo "Merge request URL:"
    echo "$mr_url"
}

# Check CI/CD pipelines in browser
pipelines_check() {
    local repo_url
    repo_url=$(get_repo_url_http) || return 1
    local url="${repo_url}/-/pipelines"

    echo "Opening pipeline URL: $url" >&2
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
    local subdomain="$1"
    if [[ -z "$subdomain" ]]; then
        echo "Usage: replace_dev_domain <subdomain> (e.g., replace_dev_domain dev18)" >&2
        return 1
    fi

    find ./dist/ -type f \
        -exec grep -lE 'https://(.*)onepay.vn' {} + \
        | xargs -r sed -i "s|https://\(.*\)onepay.vn|https://${subdomain}.onepay.vn|g"
}

# Build Angular project with watch mode
watch_angular() {
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

    if ! command -v nvm >/dev/null; then
        echo "Error: nvm is required" >&2
        return 1
    fi

    nvm use 16 || { echo "Error: Failed to switch to Node.js Mus16" >&2; return 1; }

    local cmd="ng build --configuration production --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/ --watch --optimization=false --build-optimizer=false"
    echo "Running command: $cmd" >&2
    eval "$cmd"
}

# Sync theme files to remote server
sync_theme() {
    local args
    declare -A args
    parse_args args "$@"

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

    local remote_dir="/usr/share/nginx/onepay.vn/paygate/${theme}/"
    echo "Syncing theme to ${args[user]}@${args[host]}:${remote_dir}" >&2
    rsync -av --progress --delete -e "ssh -p ${args[port]}" "dist/paygate/${theme}/" "${args[user]}@${args[host]}:${remote_dir}"
    return $?
}

sync_theme_dev18() {
    local args
    declare -A args
    parse_args args "$@"

    local theme="${args[theme]:-$(get_theme_name)}"
    if [[ -z "$theme" ]]; then
        echo "Error: --theme required or must be in a paygate theme repository" >&2
        return 1
    fi

    local rsync_remote_dir="/home/${args[user]}/${theme}/"
    echo "Syncing theme to ${args[user]}@dev18:${rsync_remote_dir}" >&2
    rsync -av --progress --delete -e "ssh -p ${args[port]}" "dist/paygate/${theme}/" "${args[user]}@dev18:${rsync_remote_dir}"

	local target_remote_dir="/usr/share/nginx/onepay.vn/paygate/${theme}"
	ssh_execute_command --user "${args[user]}" --host "${args[host]}" --port "${args[port]}" \
		--command "sudo rm -rf \"$target_remote_dir\" && sudo cp -r \"$rsync_remote_dir\" \"$target_remote_dir\""
    return $?
}

# Build theme and sync to remote server
build_theme_and_sync() {
    local args
    declare -A args
    parse_args args "$@"

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
    parse_args args "$@"

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
    ssh -p "${args[port]}" "${args[user]}@${args[host]}" "${args[remote_cmd]}"
    return $?
}

# Sync files to a remote server using rsync and fzf
ssh_fzf_sync() {
    local args
    declare -A args
    parse_args args "$@"

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
        dest="${args[user]}@${args[host]}:${remote_path}"

        echo "Syncing $src to $dest" >&2
        rsync -avz -e "ssh -p ${args[port]}" "$src" "$dest"
        rsync_exit_code=$?
        if [[ $rsync_exit_code -ne 0 ]]; then
            echo "Error syncing $file_path (exit code $rsync_exit_code)" >&2
            exit_code=$rsync_exit_code
        fi
    done <<< "$selected_files"

    return $exit_code
}

# Sync files and execute a command
ssh_fzf_sync_and_execute() {
    local args
    declare -A args
    parse_args args "$@"

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
