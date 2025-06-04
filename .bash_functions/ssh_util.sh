#!/bin/bash

ssh_fzf_sync_and_execute() {
	if [ "$#" -ne 6 ]; then
		echo "Usage: ssh_fzf_sync_and_execute source_dir ssh_user ssh_host ssh_port rsync_base_dir remote_command"
		return 1
	fi

	SOURCE_DIR="$1"
	SSH_USER="$2"
	SSH_HOST="$3"
	SSH_PORT="$4"
	RSYNC_BASE_DIR="$5"
	REMOTE_CMD="$6"

	ssh_fzf_sync "$SOURCE_DIR" "$SSH_USER" "$SSH_HOST" "$SSH_PORT" "$RSYNC_BASE_DIR"

	if [ $? -ne 0 ]; then
		echo "Sync failed."
		return $?
	fi

	ssh_execute_command "$SSH_USER" "$SSH_HOST" "$SSH_PORT" "$REMOTE_CMD"
	return $?
}

ssh_fzf_sync() {
	if [ "$#" -ne 5 ]; then
		echo "Usage: ssh_fzf_sync source_dir ssh_user ssh_host ssh_port rsync_base_dir"
		return 1
	fi

	SOURCE_DIR="$1"
	SSH_USER="$2"
	SSH_HOST="$3"
	SSH_PORT="$4"
	RSYNC_BASE_DIR="$5"

	SELECTED_FILES=$(find $SOURCE_DIR -type f | sed 's|^$SOURCE_DIR||' | fzf --multi)

	if [ -z "$SELECTED_FILES" ]; then
		echo "No files selected."
		return 0
	fi

	local EXIT_CODE=0

	echo "$SELECTED_FILES" | while read -r FILE_PATH; do
		SRC="$FILE_PATH"
		REMOTE_PATH=$(echo "$FILE_PATH" | sed 's|^'"$SOURCE_DIR"'||' | sed 's|^/||')
		DEST="$SSH_USER@$SSH_HOST:$RSYNC_BASE_DIR$REMOTE_PATH"

		echo "Syncing $SRC to $DEST"
		rsync -avz -e "ssh -p $SSH_PORT" "$SRC" "$DEST"
		RSYNC_EXIT_CODE=$?
		if [ $RSYNC_EXIT_CODE -ne 0 ]; then
			echo "Error syncing $FILE_PATH (exit code $RSYNC_EXIT_CODE)"
			EXIT_CODE=$RSYNC_EXIT_CODE
		fi
	done

return $EXIT_CODE
}

ssh_execute_command() {
	if [ "$#" -ne 4 ]; then
		echo "Usage: ssh_execute_command ssh_user ssh_host ssh_port \"command\""
		return 1
	fi

	SSH_USER="$1"
	SSH_HOST="$2"
	SSH_PORT="$3"
	REMOTE_CMD="$4"

	echo "Executing remote command on $SSH_USER@$SSH_HOST:$SSH_PORT"
	ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$REMOTE_CMD"
	return $?
}
