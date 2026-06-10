#!/bin/bash
# plex-safe-reboot.sh
# Checks Plex for active streams before rebooting
# Designed to run as a systemd service
# Configuration: /etc/plex-safe-reboot/config

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Set PATH explicitly for systemd compatibility
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Default configuration file location
CONFIG_FILE="${CONFIG_FILE:-/etc/plex-safe-reboot/config}"

# Variables to track command-line overrides
CLI_DRY_RUN=""
CLI_DEBUG=""

# Parse command line arguments before loading config
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            # Open the config file in nano (uses CONFIG_FILE variable)
            if [[ -f "$CONFIG_FILE" ]]; then
                nano "$CONFIG_FILE"
            else
                echo "Error: Configuration file not found: $CONFIG_FILE" >&2
                echo "Expected location: $CONFIG_FILE" >&2
                exit 1
            fi
            exit 0
            ;;
        --dry-run)
            CLI_DRY_RUN="true"
            shift
            ;;
        --debug)
            CLI_DEBUG="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --config         Open configuration file in nano"
            echo "  --dry-run        Test mode - don't actually reboot"
            echo "  --debug          Enable detailed debug logging"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Configuration file: $CONFIG_FILE"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Load configuration from file
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
        exit 1
    fi
    
    # Source the config file
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    
    # Validate required configuration
    if [[ -z "${PLEX_TOKEN:-}" ]]; then
        echo "ERROR: PLEX_TOKEN not set in $CONFIG_FILE" >&2
        echo "Get token from: Plex Web > Settings > Account > Show Advanced" >&2
        exit 1
    fi
    
    # Set defaults for optional configuration
    PLEX_SERVER="${PLEX_SERVER:-http://127.0.0.1:32400}"
    CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
    MAX_WAIT_TIME="${MAX_WAIT_TIME:-7200}"
    MAX_WAIT_TIME_ENABLED="${MAX_WAIT_TIME_ENABLED:-true}"
    FORCE_REBOOT="${FORCE_REBOOT:-false}"
    SCRIPT_DIR="${SCRIPT_DIR:-/usr/local/bin/scripts/plex-safe-reboot}"
    LOGFILE="${LOGFILE:-/var/log/plex-safe-reboot/plex-reboot.log}"
    LOG_FILE_ROLLOVER="${LOG_FILE_ROLLOVER:-true}"
    LOG_FILE_ROLLOVER_DAYS="${LOG_FILE_ROLLOVER_DAYS:-30}"
    DEBUG="${DEBUG:-false}"
    DRY_RUN="${DRY_RUN:-false}"
    
    # Apply command-line overrides (these take precedence over config file)
    if [[ -n "$CLI_DRY_RUN" ]]; then
        DRY_RUN="$CLI_DRY_RUN"
    fi
    if [[ -n "$CLI_DEBUG" ]]; then
        DEBUG="$CLI_DEBUG"
    fi
}

# Function to rotate log files
rotate_logs() {
    if [[ "$LOG_FILE_ROLLOVER" != true ]]; then
        return 0
    fi
    
    if [[ ! -f "$LOGFILE" ]]; then
        return 0
    fi
    
    # Find and delete log files older than specified days
    local log_dir
    log_dir="$(dirname "$LOGFILE")"
    
    if [[ -d "$log_dir" ]]; then
        find "$log_dir" -name "*.log.*" -type f -mtime +"$LOG_FILE_ROLLOVER_DAYS" -delete 2>/dev/null || true
    fi
    
    # Check if current log file is larger than 10MB
    local log_size
    log_size=$(stat -f%z "$LOGFILE" 2>/dev/null || stat -c%s "$LOGFILE" 2>/dev/null || echo 0)
    
    if [[ $log_size -gt 10485760 ]]; then
        # Rotate the log file
        local timestamp
        timestamp=$(date '+%Y%m%d-%H%M%S')
        mv "$LOGFILE" "${LOGFILE}.${timestamp}" 2>/dev/null || true
        touch "$LOGFILE"
        log "Log file rotated: ${LOGFILE}.${timestamp}"
    fi
}

# Function to log messages
log() {
    local message="[$(date '+%F %T')] $1"
    echo "$message"
    if [[ -w "$(dirname "$LOGFILE")" ]] || mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null; then
        echo "$message" >> "$LOGFILE"
    fi
}

# Function to log debug messages (only when DEBUG=true)
debug_log() {
    if [[ "$DEBUG" == true ]]; then
        local message="[$(date '+%F %T')] DEBUG: $1"
        echo "$message"
        if [[ -w "$(dirname "$LOGFILE")" ]] || mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null; then
            echo "$message" >> "$LOGFILE"
        fi
    fi
}

# Function to write debug messages directly to log file only (for functions that return values)
debug_log_file_only() {
    if [[ "$DEBUG" == true ]]; then
        echo "[$(date '+%F %T')] DEBUG: $1" >> "$LOGFILE" 2>/dev/null || true
    fi
}

# Function to validate Plex server connectivity
validate_plex_server() {
    local token="$1"
    local curl_cmd
    
    # Find curl command
    if command -v /usr/bin/curl >/dev/null 2>&1; then
        curl_cmd="/usr/bin/curl"
    elif command -v curl >/dev/null 2>&1; then
        curl_cmd="curl"
    else
        log "ERROR: curl command not found"
        return 1
    fi
    
    debug_log "Testing connection to Plex server: $PLEX_SERVER"
    
    if ! $curl_cmd -sf --max-time 10 "$PLEX_SERVER/?X-Plex-Token=$token" >/dev/null 2>&1; then
        log "ERROR: Cannot connect to Plex server at $PLEX_SERVER"
        return 1
    fi
    return 0
}

# Function to check active streams using JSON parsing
check_streams() {
    local token="$1"
    local response curl_cmd
    
    # Find curl command
    if command -v /usr/bin/curl >/dev/null 2>&1; then
        curl_cmd="/usr/bin/curl"
    elif command -v curl >/dev/null 2>&1; then
        curl_cmd="curl"
    else
        log "ERROR: curl command not found"
        return 1
    fi
    
    # Get sessions data with error handling
    if ! response=$($curl_cmd -sf --max-time 30 "$PLEX_SERVER/status/sessions?X-Plex-Token=$token" 2>/dev/null); then
        # Write directly to log file to avoid contaminating stdout
        echo "[$(date '+%F %T')] WARNING: Failed to connect to Plex server" >> "$LOGFILE" 2>/dev/null || true
        return 1
    fi
    
    # Debug: log the response size to verify we got data (to log file only)
    local response_size=${#response}
    debug_log_file_only "Plex API response size: $response_size bytes"
    
    # Simple and reliable stream counting
    local count=0
    
    # Count <Video tags directly using a simple loop
    while IFS= read -r line; do
        if [[ "$line" == *"<Video"* ]]; then
            ((count++))
        fi
    done <<< "$response"
    
    # Log to file only, not stdout
    debug_log_file_only "Stream count calculation result: $count"
    # Return clean result to stdout
    echo "$count"
    return 0
}

# Function to perform reboot
do_reboot() {
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would reboot system now"
        return 0
    fi
    
    log "Initiating system reboot..."
    # Try multiple reboot methods for compatibility
    if command -v /usr/bin/systemctl >/dev/null 2>&1; then
        /usr/bin/systemctl reboot
    elif command -v /bin/systemctl >/dev/null 2>&1; then
        /bin/systemctl reboot
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl reboot
    elif [[ -x /sbin/reboot ]]; then
        /sbin/reboot
    elif [[ -x /usr/sbin/reboot ]]; then
        /usr/sbin/reboot
    else
        log "ERROR: No reboot command found"
        return 1
    fi
}

# Function to handle script termination
cleanup() {
    log "Script terminated by signal"
    exit 130
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main script execution
main() {
    # Load configuration
    load_config
    
    # Rotate logs if needed
    rotate_logs
    
    log "############### Safe Plex Reboot Script Started ###############"
    log "Configuration loaded from: $CONFIG_FILE"
    log "Plex Server: $PLEX_SERVER"
    log "Check Interval: $((CHECK_INTERVAL / 60)) minutes"
    if [[ "$MAX_WAIT_TIME_ENABLED" == true ]]; then
        log "Max Wait Time: $((MAX_WAIT_TIME / 60)) minutes (enabled)"
    else
        log "Max Wait Time: disabled (will wait indefinitely for streams to end)"
    fi
    log "Debug Mode: $DEBUG"
    log "Dry Run: $DRY_RUN"
    log "Force Reboot: $FORCE_REBOOT"
    
    # Check if running as root for reboot capability
    if [[ $EUID -ne 0 && "$DRY_RUN" == false ]]; then
        log "WARNING: Not running as root. Reboot command may fail."
    fi
    
    # Validate Plex server connectivity
    if ! validate_plex_server "$PLEX_TOKEN"; then
        exit 1
    fi
    
    log "Plex server connectivity verified"
    
    # Force reboot if requested
    if [[ "$FORCE_REBOOT" == true ]]; then
        log "Force reboot requested, skipping stream check"
        do_reboot
        exit 0
    fi
    
    # Main checking loop
    local start_time current_time elapsed_time active_streams
    start_time=$(date +%s)
    
    while true; do
        # Check for streams with simple integer handling
        if active_streams=$(check_streams "$PLEX_TOKEN"); then
            debug_log "Received stream count: $active_streams"
            
            # Direct integer comparison without string manipulation
            if [[ $active_streams -eq 0 ]]; then
                log "No active Plex streams detected (count: $active_streams). Proceeding with reboot."
                do_reboot
                exit 0
            else
                log "$active_streams active Plex stream(s) detected. Postponing reboot."
            fi
        else
            log "Failed to check Plex streams (connection error). Will retry..."
        fi
        
        # Check if we've been waiting too long (only if MAX_WAIT_TIME is enabled)
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        
        if [[ "$MAX_WAIT_TIME_ENABLED" == true ]] && [[ $elapsed_time -ge $MAX_WAIT_TIME ]]; then
            log "Maximum wait time ($((MAX_WAIT_TIME / 60)) minutes) reached. Proceeding with reboot."
            do_reboot
            exit 0
        fi
        
        if [[ "$MAX_WAIT_TIME_ENABLED" == true ]]; then
            log "Waiting $((CHECK_INTERVAL / 60)) minutes before next check... (Total wait: $((elapsed_time / 60)) min / Max: $((MAX_WAIT_TIME / 60)) min)"
        else
            log "Waiting $((CHECK_INTERVAL / 60)) minutes before next check... (Total wait: $((elapsed_time / 60)) min / No max limit)"
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# Run main function
main "$@"
