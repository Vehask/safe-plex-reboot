#!/bin/bash
# safe-plex-reboot.sh
# Checks Plex for active streams before rebooting
# Usage: ./safe-plex-reboot.sh [--force] [--dry-run]
# Requires: PLEX_TOKEN environment variable or config file

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Set PATH explicitly for cron compatibility
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Set HOME if not set (for cron compatibility)
if [[ -z "${HOME:-}" ]]; then
    HOME="$(getent passwd "$(whoami)" | cut -d: -f6)"
    export HOME
fi

# Configuration with cron-safe defaults
PLEX_SERVER="${PLEX_SERVER:-http://127.0.0.1:32400}"
LOGFILE="${LOGFILE:-/var/log/update-logs/update.log}"
CONFIG_FILE="${HOME}/.config/plex-reboot.conf"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"  # 5 minutes
MAX_WAIT_TIME="${MAX_WAIT_TIME:-7200}"   # 2 hours max wait

# Debug mode - set to true to enable detailed logging
DEBUG="${DEBUG:-false}"

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Command line options
FORCE_REBOOT=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_REBOOT=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force] [--dry-run] [--debug] [--help]"
            echo "  --force    Skip stream check and reboot immediately"
            echo "  --dry-run  Show what would happen without rebooting"
            echo "  --debug    Enable detailed debug logging"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

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

# Function to get Plex token
get_plex_token() {
    # Try environment variable first
    if [[ -n "${PLEX_TOKEN:-}" ]]; then
        echo "$PLEX_TOKEN"
        return 0
    fi
    
    # Try multiple config file locations for cron compatibility
    local config_locations=(
        "$CONFIG_FILE"
        "${SCRIPT_DIR}/plex-reboot.conf"
        "/etc/plex-reboot.conf"
        "${HOME}/.plex-reboot.conf"
    )
    
    for config in "${config_locations[@]}"; do
        if [[ -r "$config" ]]; then
            local token
            token=$(grep -E "^PLEX_TOKEN=" "$config" 2>/dev/null | cut -d= -f2- | tr -d '"'"'"'' | xargs)
            if [[ -n "$token" ]]; then
                echo "$token"
                return 0
            fi
        fi
    done
    
    log "ERROR: PLEX_TOKEN not found in environment or config files"
    log "Checked locations: ${config_locations[*]}"
    log "Get token from: Plex Web > Settings > Account > Show Advanced"
    exit 1
}

# Function to validate Plex server connectivity
validate_plex_server() {
    local token="$1"
    local curl_cmd
    
    # Find curl command (cron-safe)
    if command -v /usr/bin/curl >/dev/null 2>&1; then
        curl_cmd="/usr/bin/curl"
    elif command -v curl >/dev/null 2>&1; then
        curl_cmd="curl"
    else
        log "ERROR: curl command not found"
        return 1
    fi
    
    if ! $curl_cmd -sf --max-time 10 "$PLEX_SERVER/?X-Plex-Token=$token" >/dev/null 2>&1; then
        log "ERROR: Cannot connect to Plex server at $PLEX_SERVER"
        return 1
    fi
    return 0
}

# Function to check active streams using JSON parsing
check_streams() {
    local token="$1"
    local response sessions curl_cmd
    
    # Find curl command (cron-safe)
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
    # Try multiple reboot methods for cron compatibility
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
    log "Script terminated by user"
    exit 130
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main script execution
main() {
    log "############### Safe Plex Reboot Script Started ###############"
    
    # Check if running as root for reboot capability
    if [[ $EUID -ne 0 && "$DRY_RUN" == false ]]; then
        log "WARNING: Not running as root. Reboot command may fail."
    fi
    
    # Get and validate Plex token
    local plex_token
    plex_token=$(get_plex_token)
    
    # Validate Plex server connectivity
    if ! validate_plex_server "$plex_token"; then
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
        if active_streams=$(check_streams "$plex_token"); then
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
        
        # Check if we've been waiting too long
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        
        if [[ $elapsed_time -ge $MAX_WAIT_TIME ]]; then
            log "Maximum wait time ($((MAX_WAIT_TIME / 60)) minutes) reached. Proceeding with reboot."
            do_reboot
            exit 0
        fi
        
        log "Waiting $((CHECK_INTERVAL / 60)) minutes before next check... (Total wait: $((elapsed_time / 60)) min)"
        sleep "$CHECK_INTERVAL"
    done
}

# Run main function
main "$@"
