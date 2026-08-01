#!/usr/bin/env bash
set -euo pipefail

### GLOBAL CONSTANTS ###
# Error Codes
readonly EC_MISSING_DEPS=1
readonly EC_KVM_PERMISSION=2
readonly EC_COMPOSE_INVALID=3
readonly EC_CONTAINER_FAILED=4
readonly EC_PORT_IN_USE=5
readonly EC_YQ_DOWNLOAD_FAILED=6
readonly EC_INVALID_ARG=7
readonly EC_TIMEOUT=8

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Paths
SCRIPT_DIR_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd) || exit 1
readonly SCRIPT_DIR_PATH
readonly DEFAULT_COMPOSE_PATHS=(
    "${HOME}/.config/winapps/compose.yaml"
    "${SCRIPT_DIR_PATH}/compose.yaml"
)
readonly YQ_PATH="${HOME}/.local/bin/yq"

### GLOBAL VARIABLES ###
COMPOSE_PATH=""
DEBUG=${DEBUG:-false}
CONTAINER_NAME=""
IMAGE=""
VERSION=""
DISK_SIZE=""
RAM_SIZE=""
CPU_CORES=""
USERNAME=""
PASSWORD=""
WIN_HOME=""
RESTART_POLICY=""
VOLUMES=()

### FUNCTIONS ###
# Error handling
error_exit() {
    local exit_code=$1
    local message=$2
    printf "%b[ERROR]%b %s\n" "${RED}" "${NC}" "$message" >&2
    log "[ERROR] $message"
    exit "$exit_code"
}

warn() {
    local message=$1
    printf "%b[WARNING]%b %s\n" "${YELLOW}" "${NC}" "$message" >&2
    if [[ "$DEBUG" = "true" ]]; then
        mkdir -p "${HOME}/.local/share/winapps" 2>/dev/null && \
        printf "[WARNING] %s\n" "$message" >> "${HOME}/.local/share/winapps/start-podman.log" || \
        printf "%b[WARNING]%b Failed to create log directory.\n" "${YELLOW}" "${NC}" >&2
    fi
}

info() {
    local message=$1
    printf "%b[INFO]%b %s\n" "${GREEN}" "${NC}" "$message"
    log "[INFO] $message"
}

# Help
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Start a Windows VM in rootless Podman without podman-compose and open the VNC web interface.

Options:
  --compose-path PATH   Specify a custom path to compose.yaml
  --help                Show this help message

Environment Variables:
  DEBUG=true            Enable debug logging

Example:
  $(basename "$0") --compose-path /custom/path/compose.yaml
EOF
}

# Logging (only if DEBUG=true)
log() {
    if [[ "$DEBUG" = "true" ]]; then
        if mkdir -p "${HOME}/.local/share/winapps" 2>/dev/null; then
            local timestamp
            timestamp=$(date +"%Y-%m-%d %H:%M:%S")
            printf "[%s] %s\n" "$timestamp" "$1" >> "${HOME}/.local/share/winapps/start-podman.log"
        else
            printf "%b[WARNING]%b Failed to create log directory.\n" "${YELLOW}" "${NC}" >&2
        fi
    fi
}

# Dependencies
check_dependencies() {
    local deps=("curl" "podman" "sha256sum")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            error_exit "$EC_MISSING_DEPS" "$dep is not installed. Please install $dep first."
        fi
    done
}

check_kvm() {
    if [ ! -e "/dev/kvm" ]; then
        error_exit "$EC_KVM_PERMISSION" "/dev/kvm does not exist. KVM acceleration is required."
    fi
    if [ ! -r "/dev/kvm" ] || [ ! -w "/dev/kvm" ]; then
        error_exit "$EC_KVM_PERMISSION" "No read/write permissions for /dev/kvm. Add user to 'kvm' group and reboot."
    fi
}

check_podman_version() {
    local podman_version
    podman_version=$(podman --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    local required_version="4.0.0"

    if [[ -z "$podman_version" ]]; then
        error_exit "$EC_MISSING_DEPS" "Podman version could not be determined. Required: >= $required_version"
    fi

    # Split versions into arrays for numerical comparison
    IFS='.' read -ra podman_parts <<< "$podman_version"
    IFS='.' read -ra required_parts <<< "$required_version"

    # Compare each part numerically
    for i in {0..2}; do
        if (( ${podman_parts[$i]:-0} < ${required_parts[$i]:-0} )); then
            error_exit "$EC_MISSING_DEPS" "Podman version $podman_version is too old. Required: >= $required_version"
        elif (( ${podman_parts[$i]:-0} > ${required_parts[$i]:-0} )); then
            return 0  # Podman version is newer
        fi
    done

    # If all parts are equal, it's okay
    return 0
}

check_local_bin_permissions() {
    local local_bin="${HOME}/.local/bin"

    if [ ! -d "$local_bin" ]; then
        if ! mkdir -p "$local_bin"; then
            error_exit "$EC_YQ_DOWNLOAD_FAILED" "Failed to create directory: $local_bin"
        fi
    fi

    if [ ! -w "$local_bin" ]; then
        error_exit "$EC_YQ_DOWNLOAD_FAILED" "No write permissions for: $local_bin"
    fi
}

get_yq_checksum() {
    # Direct download of checksum file (no REST API, no rate limiting)
    local checksum_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64.sha256"
    local checksum
    checksum=$(curl -sfL "$checksum_url" 2>/dev/null | awk '{print $1}') || true

    if [[ -n "$checksum" && "$checksum" =~ ^[a-fA-F0-9]{64}$ ]]; then
        echo "$checksum"
        return 0
    else
        error_exit "$EC_YQ_DOWNLOAD_FAILED" "Failed to fetch valid yq SHA256 checksum from GitHub."
    fi
}

verify_yq_checksum() {
    local file=$1
    local checksum=$2
    local computed_checksum

    computed_checksum=$(sha256sum "$file" | awk '{print $1}')

    if [ "$computed_checksum" != "$checksum" ]; then
        rm -f "$file"  # Remove potentially malicious file
        error_exit "$EC_YQ_DOWNLOAD_FAILED" "Downloaded yq checksum does not match. Expected: $checksum, Got: $computed_checksum"
    fi
}

install_yq() {
    # Check if yq is already installed and executable
    if [[ -x "$YQ_PATH" ]]; then
        info "yq is already installed and executable."
        return 0
    fi

    # Check if yq is in PATH
    if command -v yq &>/dev/null; then
        info "yq is in PATH. Using system yq."
        ln -sf "$(command -v yq)" "$YQ_PATH" || error_exit "$EC_YQ_DOWNLOAD_FAILED" "Failed to create symlink for yq."
        return 0
    fi

    # Create ~/.local/bin if it doesn't exist
    check_local_bin_permissions

    # Download yq (latest version)
    info "Downloading latest yq..."
    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    local tmp_yq
    tmp_yq=$(mktemp)
    trap 'rm -f "$tmp_yq"' EXIT
    
    if ! curl -sfL "$yq_url" -o "$tmp_yq"; then
        error_exit "$EC_YQ_DOWNLOAD_FAILED" "Failed to download yq. Check your internet connection."
    fi

    # Get checksum (try to fetch from GitHub)
    local expected_checksum
    expected_checksum=$(get_yq_checksum)

    # Verify checksum (if available)
    verify_yq_checksum "$tmp_yq" "$expected_checksum"

    chmod +x "$tmp_yq" || error_exit "$EC_YQ_DOWNLOAD_FAILED" "Failed to make yq executable."
    mv "$tmp_yq" "$YQ_PATH"
    trap - EXIT

    # Verify yq works
    if ! "$YQ_PATH" --version &>/dev/null; then
        error_exit "$EC_YQ_DOWNLOAD_FAILED" "Downloaded yq is not executable. Check the binary."
    fi
}

# Mapping function: LANG to dockur Windows language
get_language_from_lang() {
    local lang=$1
    local lang_code="${lang%%_*}"  # Extract language code (e.g., "de" from "de_DE.UTF-8")

    # Mapping from language codes to dockur language names
    case "$lang_code" in
        de) echo "German" ;;
        fr) echo "French" ;;
        es) echo "Spanish" ;;
        it) echo "Italian" ;;
        en) echo "English" ;;
        ru) echo "Russian" ;;
        pt) echo "Portuguese" ;;
        nl) echo "Dutch" ;;
        pl) echo "Polish" ;;
        cs) echo "Czech" ;;
        sk) echo "Slovak" ;;
        hu) echo "Hungarian" ;;
        ro) echo "Romanian" ;;
        bg) echo "Bulgarian" ;;
        hr) echo "Croatian" ;;
        sl) echo "Slovenian" ;;
        fi) echo "Finnish" ;;
        sv) echo "Swedish" ;;
        da) echo "Danish" ;;
        no) echo "Norwegian" ;;
        el) echo "Greek" ;;
        he) echo "Hebrew" ;;
        ar) echo "Arabic" ;;
        zh) echo "Chinese" ;;
        ja) echo "Japanese" ;;
        ko) echo "Korean" ;;
        th) echo "Thai" ;;
        tr) echo "Turkish" ;;
        uk) echo "Ukrainian" ;;
        lt) echo "Lithuanian" ;;
        lv) echo "Latvian" ;;
        et) echo "Estonian" ;;
        *) echo "English" ;;  # Fallback to English
    esac
}

# Parse all compose values in a single yq call (safe, no eval)
parse_compose_config() {
    local compose_path=$1
    if [ ! -f "$compose_path" ] || [ ! -r "$compose_path" ]; then
        error_exit "$EC_COMPOSE_INVALID" "Compose file not found or not readable at: $compose_path"
    fi

    # Read all values as separate lines (one per line)
    local yq_out
    yq_out=$("$YQ_PATH" eval -r '
        .services.windows.container_name // "",
        .services.windows.image // "",
        .services.windows.environment.VERSION // "",
        .services.windows.environment.DISK_SIZE // "",
        .services.windows.environment.RAM_SIZE // "",
        .services.windows.environment.CPU_CORES // "",
        .services.windows.environment.USERNAME // "",
        .services.windows.environment.PASSWORD // "",
        .services.windows.environment.HOME // "",
        .services.windows.restart // ""
    ' "$compose_path")

    # Read into array (one value per line)
    local values=()
    mapfile -t values <<< "$yq_out"

    # Assign to variables
    CONTAINER_NAME="${values[0]}"
    IMAGE="${values[1]}"
    VERSION="${values[2]}"
    DISK_SIZE="${values[3]}"
    RAM_SIZE="${values[4]}"
    CPU_CORES="${values[5]}"
    USERNAME="${values[6]}"
    PASSWORD="${values[7]}"
    WIN_HOME="${values[8]}"
    RESTART_POLICY="${values[9]}"
    
    # Parse volumes from compose.yaml (if available)
    local volumes_raw
    volumes_raw=$("$YQ_PATH" eval -r '.services.windows.volumes // [] | join("\n")' "$compose_path")
    if [[ -n "$volumes_raw" ]] && [[ "$volumes_raw" != "null" ]]; then
        IFS=$'\n' read -ra VOLUMES <<< "$volumes_raw"
    else
        # Fallback: Use default volumes if none specified in compose.yaml
        VOLUMES=("data:/storage" "$(dirname "$compose_path")/oem:/oem")
    fi

    # Validate required fields
    if [[ -z "${CONTAINER_NAME:-}" ]] || [[ -z "${IMAGE:-}" ]] || [[ -z "${VERSION:-}" ]]; then
        error_exit "$EC_COMPOSE_INVALID" "Missing essential fields in compose.yaml"
    fi
}

# Network
check_ports() {
    local ports=("8006" "3389")
    for port in "${ports[@]}"; do
        if command -v ss &>/dev/null; then
            if ss -tuln | grep -qE ":$port([[:space:]]|$)"; then
                error_exit "$EC_PORT_IN_USE" "Port $port is already in use. Stop the conflicting service first."
            fi
        elif command -v netstat &>/dev/null; then
            if netstat -tuln | grep -qE ":$port([[:space:]]|$)"; then
                error_exit "$EC_PORT_IN_USE" "Port $port is already in use. Stop the conflicting service first."
            fi
        else
            warn "Neither 'ss' nor 'netstat' is available. Skipping port check for $port."
        fi
    done
    info "Ports 8006 and 3389 are available."
}

# Container
start_container() {
    local compose_path=$1
    parse_compose_config "$compose_path"

    # Extract region and keyboard from LANG (following dockur/windows standard)
    local current_lang="${LANG:-en_US.UTF-8}"
    local winregion="${current_lang%.*}"    # Entfernt .UTF-8 → de_DE
    winregion="${winregion//_/-}"           # Ersetzt _ durch - → de-DE

    # KEYBOARD must be the same as REGION (per dockur documentation)
    local winkeyboard="$winregion"          # Gleich wie winregion (z. B. de-DE)
    
    # Get Windows language from LANG (mapping to dockur language codes)
    local windows_language
    windows_language=$(get_language_from_lang "$current_lang")

    # Log the detected settings
    info "Detected keyboard layout: $winkeyboard, region: $winregion, Windows language: $windows_language"

    # Create volumes from compose.yaml and prepare volume arguments
    local volume_args=()
    for volume in "${VOLUMES[@]}"; do
        # Safe variable expansion per volume entry (HOME, PWD, ~)
        volume="${volume//\$\{HOME\}/$HOME}"
        volume="${volume//\$HOME/$HOME}"
        volume="${volume/#\~\//$HOME/}"
        volume="${volume/#\~:/$HOME:}"
        volume="${volume//\$\{PWD\}/$PWD}"
        volume="${volume//\$PWD/$PWD}"
        
        # Extract host path (part before the first ':')
        local host_path="${volume%%:*}"
        
        # Check if volume already has :z, :Z, ,z, or ,Z suffix
        local volume_with_suffix="$volume"
        IFS=':' read -ra parts <<< "$volume"
        case "${#parts[@]}" in
            2)
                volume_with_suffix="${volume}:z"
                ;;
            3)
                # Check if options (3rd part) already contain 'z' or 'Z'
                if [[ ",${parts[2]}," =~ ,([zZ]), ]]; then
                    volume_with_suffix="$volume"
                else
                    volume_with_suffix="${volume},z"
                fi
                ;;
            *)
                volume_with_suffix="$volume"
                ;;
        esac
        
        # Check if this is a bind mount (host path starts with / or .)
        if [[ "$host_path" == /* || "$host_path" == .* ]]; then
            info "Using bind mount: $volume_with_suffix"
            
            # Resolve host path to absolute path for SELinux check
            local abs_host_path
            abs_host_path=$(realpath -m "$host_path" 2>/dev/null || readlink -f "$host_path" 2>/dev/null || echo "$host_path")
            
            # Check SELinux context
            if [[ "$abs_host_path" == "/home"* || "$abs_host_path" == "/var/home"* ]] && command -v selinuxenabled &>/dev/null && selinuxenabled; then
                if [[ -e "$abs_host_path" ]]; then
                    local current_context
                    current_context=$(stat -c '%C' "$abs_host_path" 2>/dev/null || true)
                    if [[ "$current_context" != *"container_file_t"* ]]; then
                        warn "SELinux blocks relabeling of '$abs_host_path' (current context: $current_context).
To fix, run one of the following:
  1. Temporary fix: sudo chcon -Rt container_file_t '$abs_host_path'
  2. Permanent fix: sudo semanage fcontext -a -t container_file_t '$abs_host_path(/.*)?' && sudo restorecon -Rv '$abs_host_path'
  3. Alternative: Move the bind mount to a path like /run/user/$(id -u)/shared"
                    fi
                fi
            fi
            volume_args+=("-v" "$volume_with_suffix")
        else
            # Named volume logic
            local volume_name="${volume%%:*}"
            if ! podman volume exists "$volume_name" &>/dev/null; then
                info "Creating volume: $volume_name"
                podman volume create --ignore "$volume_name" || warn "Failed to create volume: $volume_name"
            else
                info "Volume $volume_name already exists"
            fi
            volume_args+=("-v" "$volume_with_suffix")
        fi
    done

    local container_state
    container_state=$(podman ps --all --filter name="^${CONTAINER_NAME}$" --format '{{.Status}}' 2>/dev/null || true)
    container_state=${container_state,,}
    container_state=${container_state%% *}

    if [[ "$container_state" != "up" ]]; then
        info "Starting container $CONTAINER_NAME..."
        # Clean up any existing container with the same name
        if [ "$DEBUG" = "true" ]; then
            podman rm -f "$CONTAINER_NAME" || true
        else
            podman rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
        fi

        # Check ports only if container is not running
        check_ports

        # Build podman command (common part)
        local podman_cmd=(
            podman run
            -d
            --name "$CONTAINER_NAME"
            --device=/dev/kvm
            --device=/dev/net/tun
            --network "pasta:-t,127.0.0.1/8006:8006,-t,127.0.0.1/3389:3389,-u,127.0.0.1/3389:3389"
            "${volume_args[@]}"  # Dynamische Volumes mit :z-Suffix
            --stop-timeout 120
            --uidmap "+0:@$(id -u)"
        )
        
        # Add --rm or --restart (they are mutually exclusive in Podman)
        if [[ -n "$RESTART_POLICY" && "$RESTART_POLICY" != "no" ]]; then
            podman_cmd+=(--restart "$RESTART_POLICY")
        else
            podman_cmd+=(--rm)
        fi
        
        # Add environment variables only if they are non-empty
        if [[ -n "$VERSION" ]]; then
            podman_cmd+=(-e "VERSION=$VERSION")
        fi
        if [[ -n "$DISK_SIZE" ]]; then
            podman_cmd+=(-e "DISK_SIZE=$DISK_SIZE")
        fi
        if [[ -n "$RAM_SIZE" ]]; then
            podman_cmd+=(-e "RAM_SIZE=$RAM_SIZE")
        fi
        if [[ -n "$CPU_CORES" ]]; then
            podman_cmd+=(-e "CPU_CORES=$CPU_CORES")
        fi
        if [[ -n "$USERNAME" ]]; then
            podman_cmd+=(-e "USERNAME=$USERNAME")
        fi
        if [[ -n "$PASSWORD" ]]; then
            podman_cmd+=(-e "PASSWORD=$PASSWORD")
        fi
        if [[ -n "$WIN_HOME" ]]; then
            podman_cmd+=(-e "HOME=$WIN_HOME")
        fi
        podman_cmd+=(
            -e "REGION=$winregion"
            -e "KEYBOARD=$winkeyboard"
            -e "LANGUAGE=$windows_language"
            -e "NETWORK=user"
            "$IMAGE"
        )

        # Execute podman command (with or without output)
        if [ "$DEBUG" = "true" ]; then
            "${podman_cmd[@]}" || error_exit "$EC_CONTAINER_FAILED" "Failed to start container $CONTAINER_NAME."
        else
            "${podman_cmd[@]}" > /dev/null 2>&1 || error_exit "$EC_CONTAINER_FAILED" "Failed to start container $CONTAINER_NAME."
        fi
    else
        info "Container $CONTAINER_NAME is already running."
    fi
}

check_container_ready() {
    local timeout=60
    local start_seconds=$SECONDS
    local elapsed=0

    info "Waiting for container $CONTAINER_NAME to be ready (timeout: ${timeout}s)..."
    while (( elapsed < timeout )); do
        if podman ps --filter name="^${CONTAINER_NAME}$" --format '{{.Status}}' | grep -q "Up"; then
            info "Container $CONTAINER_NAME is ready (took ${elapsed}s)."
            return 0
        fi
        # Show progress every 10 seconds
        if (( elapsed > 0 )) && (( elapsed % 10 == 0 )); then
            info "Still waiting for container $CONTAINER_NAME... (${elapsed}s/${timeout}s)"
        fi
        sleep 1
        elapsed=$(( SECONDS - start_seconds ))
    done

    error_exit "$EC_TIMEOUT" "Container $CONTAINER_NAME failed to start within $timeout seconds."
}

check_vnc_availability() {
    local host="127.0.0.1"
    local port="8006"
    local timeout=30  # Increased from 10 to 30 seconds
    local start_seconds=$SECONDS
    local elapsed=0

    info "Checking if VNC is available at $host:$port..."
    while (( elapsed < timeout )); do
        if timeout 1 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' _ "$host" "$port" &>/dev/null; then
            info "VNC is available at $host:$port (took ${elapsed}s)."
            return 0
        fi
        # Show progress every 5 seconds
        if (( elapsed > 0 )) && (( elapsed % 5 == 0 )); then
            info "Still checking VNC availability... (${elapsed}s/${timeout}s)"
        fi
        sleep 1
        elapsed=$(( SECONDS - start_seconds ))
    done

    error_exit "$EC_CONTAINER_FAILED" "VNC is not available at $host:$port after $timeout seconds."
}

### MAIN LOGIC ###
# Initialize logging directory if DEBUG is enabled
if [ "$DEBUG" = "true" ]; then
    mkdir -p "${HOME}/.local/share/winapps" || warn "Failed to create log directory."
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --compose-path)
            if [[ -z "${2:-}" ]]; then
                error_exit "$EC_INVALID_ARG" "Missing path after --compose-path."
            fi
            COMPOSE_PATH="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error_exit "$EC_INVALID_ARG" "Unknown argument: $1"
            ;;
    esac
done

# Check root
if [ "$(id -u)" = "0" ]; then
    error_exit "$EC_MISSING_DEPS" "This script must not be run as root!"
fi

# Check dependencies
info "Checking dependencies..."
check_dependencies
check_kvm
check_podman_version

# Install yq
install_yq

# Set compose path
if [[ -z "$COMPOSE_PATH" ]]; then
    for path in "${DEFAULT_COMPOSE_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            COMPOSE_PATH="$path"
            break
        fi
    done
    if [[ -z "$COMPOSE_PATH" ]]; then
        error_exit "$EC_COMPOSE_INVALID" "compose.yaml not found in standard locations."
    fi
fi

# Start container
info "Starting container..."
start_container "$COMPOSE_PATH"

# Check container is ready
check_container_ready

# Check VNC
check_vnc_availability

# Open VNC in browser
info "Opening VNC web interface at http://127.0.0.1:8006/"
xdg-open "http://127.0.0.1:8006/" || warn "Failed to open browser. Please open http://127.0.0.1:8006/ manually."

log "Script completed successfully."
exit 0
