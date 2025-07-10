##!/bin/bash
#
## Parse SSH-related arguments and store them in an associative array
#parse_args() {
#    # Store results in associative array
#    declare -n result=$1
#    shift
#
#    # Initialize defaults
#    result[user]="root"
#    result[port]="22"
#    result[host]=""
#    result[source_dir]=""
#    result[remote_dir]=""
#    result[remote_cmd]=""
#    result[theme]=""
#
#    while [[ $# -gt 0 ]]; do
#        case "$1" in
#            --user|-u)
#                result[user]="$2"
#                shift 2
#                ;;
#            --host|-h)
#                result[host]="$2"
#                shift 2
#                ;;
#            --port|-p)
#                result[port]="$2"
#                shift 2
#                ;;
#            --source-dir|-sd)
#                result[source_dir]="$2"
#                shift 2
#                ;;
#            --remote-dir|-rd)
#                result[remote_dir]="$2"
#                shift 2
#                ;;
#            --command|-cmd)
#                result[remote_cmd]="$2"
#                shift 2
#                ;;
#            --theme)
#                result[theme]="$2"
#                shift 2
#                ;;
#            *)
#                echo "Unknown argument: $1" >&2
#                return 1
#                ;;
#        esac
#    done
#}
#
## Execute command over SSH
#ssh_execute_command() {
#    local args
#    declare -A args
#    parse_args args "$@"
#
#    # Validate required arguments
#    if [[ -z "${args[host]}" || -z "${args[remote_cmd]}" ]]; then
#        echo "Error: --host/-h and --command/-cmd are required" >&2
#        return 1
#    fi
#
#    echo "Executing command on ${args[user]}@${args[host]}:${args[port]}" >&2
#    ssh -p "${args[port]}" "${args[user]}@${args[host]}" "${args[remote_cmd]}"
#    return $?
#}
#
## Sync files to a remote server using rsync and fzf
#ssh_fzf_sync() {
#    local args
#    declare -A args
#    parse_args args "$@"
#
#    # Validate required arguments
#    if [[ -z "${args[source_dir]}" || -z "${args[host]}" || -z "${args[remote_dir]}" ]]; then
#        echo "Error: --source-dir/-sd, --host/-h, and --remote-dir/-rd are required" >&2
#        return 1
#    fi
#
#    # Check dependencies
#    command -v fzf >/dev/null || { echo "Error: fzf is required" >&2; return 1; }
#    command -v rsync >/dev/null || { echo "Error: rsync is required" >&2; return 1; }
#
#    # Ensure source_dir exists
#    if [[ ! -d "${args[source_dir]}" ]]; then
#        echo "Error: ${args[source_dir]} is not a valid directory" >&2
#        return 1
#    fi
#
#    # Select files with fzf
#    selected_files=$(find "${args[source_dir]}" -type f -not -path '*/\.*' | sed "s|^${args[source_dir]}/||" | fzf --multi)
#
#    if [[ -z "$selected_files" ]]; then
#        echo "No files selected." >&2
#        return 0
#    fi
#
#    local exit_code=0
#    while IFS= read -r file_path; do
#        [[ -z "$file_path" ]] && continue
#        src="${args[source_dir]}/${file_path}"
#        remote_path="${args[remote_dir]%/}/${file_path#/}"
#        dest="${args[user]}@${args[host]}:${remote_path}"
#
#        echo "Syncing $src to $dest" >&2
#        rsync -avz -e "ssh -p ${args[port]}" "$src" "$dest"
#        rsync_exit_code=$?
#        if [[ $rsync_exit_code -ne 0 ]]; then
#            echo "Error syncing $file_path (exit code $rsync_exit_code)" >&2
#            exit_code=$rsync_exit_code
#        fi
#    done <<< "$selected_files"
#
#    return $exit_code
#}
#
## Sync files and execute a command
#ssh_fzf_sync_and_execute() {
#    local args
#    declare -A args
#    parse_args args "$@"
#
#    # Validate required arguments
#    if [[ -z "${args[source_dir]}" || -z "${args[host]}" || -z "${args[remote_dir]}" || -z "${args[remote_cmd]}" ]]; then
#        echo "Error: --source-dir/-sd, --host/-h, --remote-dir/-rd, and --command/-cmd are required" >&2
#        return 1
#    fi
#
#    # Sync files
#    ssh_fzf_sync --source-dir "${args[source_dir]}" --user "${args[user]}" --host "${args[host]}" --port "${args[port]}" --remote-dir "${args[remote_dir]}"
#    if [[ $? -ne 0 ]]; then
#        echo "Sync failed." >&2
#        return 1
#    fi
#
#    # Execute command
#    ssh_execute_command --user "${args[user]}" --host "${args[host]}" --port "${args[port]}" --command "${args[remote_cmd]}"
#    return $?
#}
