#!/bin/bash
# update.sh - Update configuration for Plex Safe Reboot Service
# This file is auto-configured during installation
# Run with: sudo ./update.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# These values are set during installation - DO NOT EDIT MANUALLY
INSTALLED_SCRIPT_DIR="__SCRIPT_DIR__"
INSTALLED_LOG_DIR="__LOG_DIR__"
INSTALLED_CONFIG_DIR="__CONFIG_DIR__"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local answer
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$(echo -e "${YELLOW}?${NC} $question [Y/n]: ")" answer
            answer="${answer:-y}"
        else
            read -p "$(echo -e "${YELLOW}?${NC} $question [y/N]: ")" answer
            answer="${answer:-n}"
        fi
        
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) print_warning "Please answer yes (y) or no (n)" ;;
        esac
    done
}

# Function to read user input with default value
read_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    
    read -p "$(echo -e "${YELLOW}?${NC} $prompt [$default]: ")" value
    echo "${value:-$default}"
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to convert day numbers to systemd format
convert_days_to_systemd() {
    local days="$1"
    local day_names=("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
    local result=""
    
    IFS=',' read -ra DAY_ARRAY <<< "$days"
    for day in "${DAY_ARRAY[@]}"; do
        day=$(echo "$day" | xargs)  # Trim whitespace
        if [[ $day -ge 1 && $day -le 7 ]]; then
            if [[ -n "$result" ]]; then
                result="${result},${day_names[$((day-1))]}"
            else
                result="${day_names[$((day-1))]}"
            fi
        fi
    done
    
    echo "$result"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    echo "Please run: sudo ./update.sh"
    exit 1
fi

# Check if installation paths are configured
if [[ "$INSTALLED_SCRIPT_DIR" == "__SCRIPT_DIR__" ]]; then
    print_error "This update script has not been configured yet"
    print_info "Please run install.sh first to set up the service"
    exit 1
fi

clear
print_header "Plex Safe Reboot Service - Configuration Update"

print_info "Current installation:"
echo "  Script Directory: $INSTALLED_SCRIPT_DIR"
echo "  Log Directory:    $INSTALLED_LOG_DIR"
echo "  Config Directory: $INSTALLED_CONFIG_DIR"
echo ""

# Load current configuration
if [[ ! -f "$INSTALLED_CONFIG_DIR/config" ]]; then
    print_error "Configuration file not found: $INSTALLED_CONFIG_DIR/config"
    exit 1
fi

# Source current config to get current values
source "$INSTALLED_CONFIG_DIR/config"

print_header "What would you like to update?"
echo "1. Plex server settings (server URL, token)"
echo "2. Timing settings (check interval, max wait time)"
echo "3. Timer schedule (when the service runs)"
echo "4. Log settings (rotation, debug mode)"
echo "5. Update script files (reinstall from current directory)"
echo "6. Full reconfiguration (all settings)"
echo "7. Exit without changes"
echo ""

while true; do
    read -p "$(echo -e "${YELLOW}?${NC} Select an option (1-7): ")" choice
    
    case $choice in
        1|2|3|4|5|6)
            break
            ;;
        7)
            print_info "No changes made. Exiting."
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-7."
            ;;
    esac
done

# Option 1: Plex server settings
if [[ $choice == "1" || $choice == "6" ]]; then
    print_header "Update Plex Server Settings"
    
    echo "Current Plex server: $PLEX_SERVER"
    if ask_yes_no "Update Plex server?" "n"; then
        if ask_yes_no "Is Plex running on localhost (this machine)?" "y"; then
            NEW_PLEX_SERVER="http://127.0.0.1:32400"
        else
            while true; do
                read -p "$(echo -e "${YELLOW}?${NC} Enter Plex server IP address: ")" plex_ip
                if validate_ip "$plex_ip"; then
                    NEW_PLEX_SERVER="http://${plex_ip}:32400"
                    break
                else
                    print_error "Invalid IP address format"
                fi
            done
        fi
        sed -i "s|^PLEX_SERVER=.*|PLEX_SERVER=\"$NEW_PLEX_SERVER\"|" "$INSTALLED_CONFIG_DIR/config"
        print_success "Plex server updated to: $NEW_PLEX_SERVER"
    fi
    
    echo ""
    if ask_yes_no "Update Plex token?" "n"; then
        print_info "Get your token from:"
        print_info "https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/"
        echo ""
        read -p "$(echo -e "${YELLOW}?${NC} Enter new Plex token: ")" new_token
        if [[ -n "$new_token" ]]; then
            sed -i "s|^PLEX_TOKEN=.*|PLEX_TOKEN=\"$new_token\"|" "$INSTALLED_CONFIG_DIR/config"
            print_success "Plex token updated"
        fi
    fi
fi

# Option 2: Timing settings
if [[ $choice == "2" || $choice == "6" ]]; then
    print_header "Update Timing Settings"
    
    echo "Current check interval: $CHECK_INTERVAL seconds ($((CHECK_INTERVAL / 60)) minutes)"
    if ask_yes_no "Update check interval?" "n"; then
        new_interval=$(read_with_default "Check interval in seconds" "$CHECK_INTERVAL")
        sed -i "s/^CHECK_INTERVAL=.*/CHECK_INTERVAL=$new_interval/" "$INSTALLED_CONFIG_DIR/config"
        print_success "Check interval updated to: $new_interval seconds"
    fi
    
    echo ""
    echo "Current max wait time: $MAX_WAIT_TIME_ENABLED (value: $MAX_WAIT_TIME seconds)"
    if ask_yes_no "Update max wait time settings?" "n"; then
        if ask_yes_no "Enable maximum wait time limit?" "y"; then
            sed -i "s/^MAX_WAIT_TIME_ENABLED=.*/MAX_WAIT_TIME_ENABLED=true/" "$INSTALLED_CONFIG_DIR/config"
            new_max=$(read_with_default "Maximum wait time in seconds" "$MAX_WAIT_TIME")
            sed -i "s/^MAX_WAIT_TIME=.*/MAX_WAIT_TIME=$new_max/" "$INSTALLED_CONFIG_DIR/config"
            print_success "Max wait time enabled: $new_max seconds"
        else
            sed -i "s/^MAX_WAIT_TIME_ENABLED=.*/MAX_WAIT_TIME_ENABLED=false/" "$INSTALLED_CONFIG_DIR/config"
            print_success "Max wait time disabled (infinite wait)"
        fi
    fi
fi

# Option 3: Timer schedule
if [[ $choice == "3" || $choice == "6" ]]; then
    print_header "Update Timer Schedule"
    
    print_info "Current timer schedule:"
    systemctl cat plex-safe-reboot.timer | grep "OnCalendar=" || echo "  (not found)"
    echo ""
    
    if ask_yes_no "Update timer schedule?" "n"; then
        if ask_yes_no "Run every day?" "n"; then
            TIMER_DAYS="*"
        else
            print_info "Enter days: 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday"
            read -p "$(echo -e "${YELLOW}?${NC} Enter days (comma-separated): ")" day_input
            TIMER_DAYS=$(convert_days_to_systemd "$day_input")
        fi
        
        read -p "$(echo -e "${YELLOW}?${NC} Enter time (HH:MM): ")" time_input
        TIMER_TIME="${time_input}:00"
        
        if [[ "$TIMER_DAYS" == "*" ]]; then
            TIMER_SCHEDULE="*-*-* $TIMER_TIME"
        else
            TIMER_SCHEDULE="$TIMER_DAYS *-*-* $TIMER_TIME"
        fi
        
        if ask_yes_no "Enable persistent mode?" "y"; then
            TIMER_PERSISTENT="true"
        else
            TIMER_PERSISTENT="false"
        fi
        
        # Update timer file
        cat > /etc/systemd/system/plex-safe-reboot.timer <<EOF
[Unit]
Description=Plex Safe Reboot Timer
Documentation=https://github.com/yourusername/plex-safe-reboot
Requires=plex-safe-reboot.service

[Timer]
# Schedule: $TIMER_SCHEDULE
OnCalendar=$TIMER_SCHEDULE

# Run on boot if the last scheduled run was missed
Persistent=$TIMER_PERSISTENT

# Randomize start time by up to 15 minutes
RandomizedDelaySec=15min

[Install]
WantedBy=timers.target
EOF
        
        systemctl daemon-reload
        systemctl restart plex-safe-reboot.timer
        print_success "Timer schedule updated: $TIMER_SCHEDULE"
    fi
fi

# Option 4: Log settings
if [[ $choice == "4" || $choice == "6" ]]; then
    print_header "Update Log Settings"
    
    echo "Current log rotation: $LOG_FILE_ROLLOVER (days: $LOG_FILE_ROLLOVER_DAYS)"
    if ask_yes_no "Update log rotation settings?" "n"; then
        if ask_yes_no "Enable log rotation?" "y"; then
            sed -i "s/^LOG_FILE_ROLLOVER=.*/LOG_FILE_ROLLOVER=true/" "$INSTALLED_CONFIG_DIR/config"
            new_days=$(read_with_default "Keep logs for how many days" "$LOG_FILE_ROLLOVER_DAYS")
            sed -i "s/^LOG_FILE_ROLLOVER_DAYS=.*/LOG_FILE_ROLLOVER_DAYS=$new_days/" "$INSTALLED_CONFIG_DIR/config"
            print_success "Log rotation enabled: $new_days days"
        else
            sed -i "s/^LOG_FILE_ROLLOVER=.*/LOG_FILE_ROLLOVER=false/" "$INSTALLED_CONFIG_DIR/config"
            print_success "Log rotation disabled"
        fi
    fi
    
    echo ""
    echo "Current debug mode: $DEBUG"
    if ask_yes_no "Update debug mode?" "n"; then
        if ask_yes_no "Enable debug mode?" "n"; then
            sed -i "s/^DEBUG=.*/DEBUG=true/" "$INSTALLED_CONFIG_DIR/config"
            print_success "Debug mode enabled"
        else
            sed -i "s/^DEBUG=.*/DEBUG=false/" "$INSTALLED_CONFIG_DIR/config"
            print_success "Debug mode disabled"
        fi
    fi
fi

# Option 5: Update script files
if [[ $choice == "5" || $choice == "6" ]]; then
    print_header "Update Script Files"
    
    CURRENT_DIR="$(pwd)"
    print_info "Current directory: $CURRENT_DIR"
    
    if [[ ! -f "$CURRENT_DIR/plex-safe-reboot.sh" ]]; then
        print_error "Script file not found in current directory"
        print_info "Please run this update script from the directory containing the new script files"
    else
        if ask_yes_no "Update script files from current directory?" "y"; then
            cp "$CURRENT_DIR/plex-safe-reboot.sh" "$INSTALLED_SCRIPT_DIR/scripts/plex-safe-reboot/"
            chmod +x "$INSTALLED_SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh"
            print_success "Script files updated"
            
            if [[ -f "$CURRENT_DIR/plex-safe-reboot.service" ]]; then
                # Update service file with correct paths
                sed "s|/usr/local/bin/scripts/plex-safe-reboot|$INSTALLED_SCRIPT_DIR/scripts/plex-safe-reboot|g" "$CURRENT_DIR/plex-safe-reboot.service" > /tmp/plex-safe-reboot.service.tmp
                sed -i "s|/var/log/plex-safe-reboot|$INSTALLED_LOG_DIR|g" /tmp/plex-safe-reboot.service.tmp
                sed -i "s|/etc/plex-safe-reboot/config|$INSTALLED_CONFIG_DIR/config|g" /tmp/plex-safe-reboot.service.tmp
                cp /tmp/plex-safe-reboot.service.tmp /etc/systemd/system/plex-safe-reboot.service
                rm /tmp/plex-safe-reboot.service.tmp
                systemctl daemon-reload
                print_success "Service file updated"
            fi
        fi
    fi
fi

print_header "Update Complete!"

print_success "Configuration has been updated"
echo ""
print_info "You can test the new configuration with:"
echo "  sudo $INSTALLED_SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh --dry-run"
echo ""
print_info "View current configuration:"
echo "  sudo cat $INSTALLED_CONFIG_DIR/config"
echo ""
print_info "Check timer status:"
echo "  sudo systemctl status plex-safe-reboot.timer"
echo ""
