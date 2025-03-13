# Base directory and prefix for SSH socket files
SOCKET_DIR="$HOME/.ssh_mux"
SOCKET_PREFIX="ssh_mux"
mkdir -p "$SOCKET_DIR"

# Function to generate a unique socket filename based on user, host, and port
ssh_mux_get_socket() {
    local user="$1"
    local host="$2"
    local port="$3"
    echo "$SOCKET_DIR/${SOCKET_PREFIX}_${user}_${host}_${port}.sock"
}

# Create an SSH master connection
ssh_mux_create_master() {
    local user="$1"
    local host="$2"
    local port="$3"
    local socket_file
    socket_file=$(ssh_mux_get_socket "$user" "$host" "$port")

    # Start the SSH master connection
    ssh -M -S "$socket_file" -p "$port" "$user@$host" -N -f
    echo "Master connection established for $user@$host:$port (socket: $socket_file)"
}

# Close a specific SSH master connection
ssh_mux_close() {
    local user="$1"
    local host="$2"
    local port="$3"
    local socket_file
    socket_file=$(ssh_mux_get_socket "$user" "$host" "$port")

    if [ -S "$socket_file" ]; then
        ssh -S "$socket_file" -O exit "$user@$host" && rm -f "$socket_file"
        echo "Closed master connection for $user@$host:$port"
    else
        echo "No active master connection for $user@$host:$port"
    fi
}

# Close all SSH master connections
ssh_mux_close_all() {
    for socket in "$SOCKET_DIR"/${SOCKET_PREFIX}_*.sock; do
        [ -S "$socket" ] && ssh -S "$socket" -O exit 2>/dev/null && rm -f "$socket"
    done
}

# List all SSH sockets
ssh_mux_list() {
    for socket in "$SOCKET_DIR"/${SOCKET_PREFIX}_*.sock; do
        [ -S "$socket" ] && echo "$socket"
    done
}
