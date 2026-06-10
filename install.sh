#!/bin/bash
# install.sh - Interactive installation script for Plex Safe Reboot Service
# Run with: sudo ./install.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_SCRIPT_DIR="/usr/local/bin"
DEFAULT_LOG_DIR="/var/log/plex-safe-reboot"
DEFAULT_CONFIG_DIR="/etc/plex-safe-reboot"

# Variables to be set during installation
SCRIPT_DIR=""
LOG_DIR=""
CONFIG_DIR="$DEFAULT_CONFIG_DIR"
PLEX_TOKEN=""
PLEX_SERVER=""
CHECK_INTERVAL=300
MAX_WAIT_TIME=7200
MAX_WAIT_TIME_ENABLED="true"
LOG_FILE_ROLLOVER="true"
LOG_FILE_ROLLOVER_DAYS=30
DEBUG="false"
TIMER_SCHEDULE=""
TIMER_PERSISTENT="true"
CREATE_ALIASES="false"

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
    echo "Please run: sudo ./install.sh"
    exit 1
fi

clear
print_header "Plex Safe Reboot Service - Interactive Installation"

# Important warning at the start
print_warning "═══════════════════════════════════════════════════════════════"
print_warning "                    IMPORTANT WARNING"
print_warning "═══════════════════════════════════════════════════════════════"
echo ""
print_warning "This service will automatically REBOOT your system when:"
echo "  • The configured schedule is reached (e.g., weekly)"
echo "  • No active Plex streams are detected"
echo "  • OR maximum wait time is exceeded (if enabled)"
echo ""
print_warning "Once the timer is enabled, your system MAY REBOOT based on"
print_warning "the schedule you configure during installation."
echo ""
print_warning "═══════════════════════════════════════════════════════════════"
echo ""

if ! ask_yes_no "Do you understand and want to continue with installation?" "y"; then
    print_info "Installation cancelled by user."
    echo "You can run this installer again when ready."
    exit 0
fi

echo ""

# Check if already installed
REINSTALL=false
if [[ -f "/etc/plex-safe-reboot/config" ]]; then
    print_warning "Existing installation detected!"
    echo ""
    if ask_yes_no "Do you want to reinstall/reconfigure?" "n"; then
        REINSTALL=true
        print_info "Proceeding with reinstallation..."
    else
        print_info "Installation cancelled. Use update.sh to modify configuration."
        exit 0
    fi
fi

print_info "This installer will guide you through the setup process."
print_info "You can press Ctrl+C at any time to cancel the installation."
echo ""

# Step 1: Script installation directory
print_header "Step 1: Script Installation Directory"
print_info "Where should the script be installed?"
print_info "Default: $DEFAULT_SCRIPT_DIR"
echo ""

if ask_yes_no "Use default script directory ($DEFAULT_SCRIPT_DIR)?" "y"; then
    SCRIPT_DIR="$DEFAULT_SCRIPT_DIR"
else
    # Get current directory
    CURRENT_DIR="$(pwd)"
    
    # If current directory is different from default, offer it as an option
    if [[ "$CURRENT_DIR" != "$DEFAULT_SCRIPT_DIR" ]]; then
        echo ""
        print_info "Current directory: $CURRENT_DIR"
        if ask_yes_no "Use current directory for script installation?" "y"; then
            SCRIPT_DIR="$CURRENT_DIR"
        else
            while true; do
                SCRIPT_DIR=$(read_with_default "Enter script installation directory" "$DEFAULT_SCRIPT_DIR")
                if ask_yes_no "Install script to: $SCRIPT_DIR - Is this correct?" "y"; then
                    break
                fi
            done
        fi
    else
        # Current directory is same as default, skip to manual input
        while true; do
            SCRIPT_DIR=$(read_with_default "Enter script installation directory" "$DEFAULT_SCRIPT_DIR")
            if ask_yes_no "Install script to: $SCRIPT_DIR - Is this correct?" "y"; then
                break
            fi
        done
    fi
fi

print_success "Script will be installed to: $SCRIPT_DIR"

# Step 2: Log directory
print_header "Step 2: Log File Directory"
print_info "Where should log files be stored?"
print_info "Default: $DEFAULT_LOG_DIR"
echo ""

if ask_yes_no "Use default log directory ($DEFAULT_LOG_DIR)?" "y"; then
    LOG_DIR="$DEFAULT_LOG_DIR"
else
    while true; do
        LOG_DIR=$(read_with_default "Enter log file directory" "$DEFAULT_LOG_DIR")
        if ask_yes_no "Store logs in: $LOG_DIR - Is this correct?" "y"; then
            break
        fi
    done
fi

print_success "Logs will be stored in: $LOG_DIR"

# Step 3: Plex Server Configuration
print_header "Step 3: Plex Server Configuration"
print_info "Configure your Plex Media Server connection"
echo ""

if ask_yes_no "Is Plex running on localhost (this machine)?" "y"; then
    PLEX_SERVER="http://127.0.0.1:32400"
    print_success "Using localhost: $PLEX_SERVER"
else
    print_info "Please enter the local IP address of your Plex server"
    print_info "Example: YOUR_PLEX_SERVER_IP"
    echo ""
    
    while true; do
        read -p "$(echo -e "${YELLOW}?${NC} Enter Plex server IP address: ")" plex_ip
        
        if validate_ip "$plex_ip"; then
            PLEX_SERVER="http://${plex_ip}:32400"
            if ask_yes_no "Use Plex server: $PLEX_SERVER - Is this correct?" "y"; then
                break
            fi
        else
            print_error "Invalid IP address format. Please try again."
        fi
    done
    
    print_success "Plex server set to: $PLEX_SERVER"
fi

# Step 4: Plex Token
print_header "Step 4: Plex Authentication Token"
print_info "You need a Plex authentication token for this service to work."
print_info "Get your token from:"
print_info "https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/"
echo ""
print_info "Steps to get your token:"
echo "  1. Sign in to your Plex account in Plex Web App"
echo "  2. Browse to a library item and view the XML for it"
echo "  3. Look in the URL and find the token as the X-Plex-Token value"
echo ""

while true; do
    read -p "$(echo -e "${YELLOW}?${NC} Enter your Plex token: ")" PLEX_TOKEN
    
    if [[ -z "$PLEX_TOKEN" ]]; then
        print_error "Plex token cannot be empty"
        continue
    fi
    
    if ask_yes_no "Token entered (hidden for security). Is this correct?" "y"; then
        break
    fi
done

print_success "Plex token configured"

# Step 5: Timing Configuration
print_header "Step 5: Timing Configuration"
print_info "Configure how often to check for streams and maximum wait time"
echo ""

CHECK_INTERVAL=$(read_with_default "Check interval in seconds (how often to check for streams)" "300")
print_success "Check interval set to: $CHECK_INTERVAL seconds ($((CHECK_INTERVAL / 60)) minutes)"

echo ""
if ask_yes_no "Enable maximum wait time limit?" "y"; then
    MAX_WAIT_TIME_ENABLED="true"
    MAX_WAIT_TIME=$(read_with_default "Maximum wait time in seconds before forcing reboot" "7200")
    print_success "Maximum wait time enabled: $MAX_WAIT_TIME seconds ($((MAX_WAIT_TIME / 60)) minutes)"
else
    MAX_WAIT_TIME_ENABLED="false"
    MAX_WAIT_TIME=7200  # Set default even if disabled
    print_success "Maximum wait time disabled - will wait indefinitely for streams to end"
fi

# Step 6: Timer Schedule Configuration
print_header "Step 6: Timer Schedule Configuration"
print_info "Configure when the service should run automatically"
echo ""

if ask_yes_no "Run every day?" "n"; then
    TIMER_DAYS="*"
    print_success "Service will run every day"
else
    print_info "Enter the days you want the service to run"
    print_info "Days: 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday"
    print_info "Separate multiple days with commas (e.g., 1,2,7 for Monday, Tuesday, and Sunday)"
    echo ""
    
    while true; do
        read -p "$(echo -e "${YELLOW}?${NC} Enter days (1-7, comma-separated): ")" day_input
        
        if [[ -n "$day_input" ]]; then
            TIMER_DAYS=$(convert_days_to_systemd "$day_input")
            if [[ -n "$TIMER_DAYS" ]]; then
                print_success "Service will run on: $TIMER_DAYS"
                break
            else
                print_error "Invalid day format. Please try again."
            fi
        else
            print_error "Days cannot be empty"
        fi
    done
fi

echo ""
print_info "Enter the time of day to run the service (24-hour format)"
print_info "Example: 03:00 for 3:00 AM, 15:30 for 3:30 PM"
echo ""

while true; do
    read -p "$(echo -e "${YELLOW}?${NC} Enter time (HH:MM): ")" time_input
    
    if [[ $time_input =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        TIMER_TIME="$time_input:00"
        print_success "Service will run at: $time_input"
        break
    else
        print_error "Invalid time format. Please use HH:MM (e.g., 03:00)"
    fi
done

# Build the timer schedule
if [[ "$TIMER_DAYS" == "*" ]]; then
    TIMER_SCHEDULE="*-*-* $TIMER_TIME"
else
    TIMER_SCHEDULE="$TIMER_DAYS *-*-* $TIMER_TIME"
fi

echo ""
if ask_yes_no "Enable persistent mode? (Run missed schedules on boot)" "y"; then
    TIMER_PERSISTENT="true"
    print_success "Persistent mode enabled"
else
    TIMER_PERSISTENT="false"
    print_success "Persistent mode disabled"
fi

# Step 7: Log Configuration
print_header "Step 7: Log Configuration"
print_info "Configure log file rotation and retention"
echo ""

if ask_yes_no "Enable automatic log file rotation?" "y"; then
    LOG_FILE_ROLLOVER="true"
    LOG_FILE_ROLLOVER_DAYS=$(read_with_default "Keep log files for how many days" "30")
    print_success "Log rotation enabled: keeping logs for $LOG_FILE_ROLLOVER_DAYS days"
else
    LOG_FILE_ROLLOVER="false"
    print_success "Log rotation disabled"
fi

echo ""
if ask_yes_no "Enable debug mode (detailed logging)?" "n"; then
    DEBUG="true"
    print_success "Debug mode enabled"
else
    DEBUG="false"
    print_success "Debug mode disabled"
fi

# Step 8: Alias Configuration
print_header "Step 8: Shell Aliases (Optional)"
print_info "Create convenient shell aliases for common operations?"
echo ""
print_info "This will add aliases like:"
echo "  • plex-safe-reboot         - Run the script"
echo "  • plex-safe-reboot-config  - Edit configuration"
echo "  • plex-safe-reboot-dry-run - Test without rebooting"
echo "  • plex-safe-reboot-debug   - Run with debug logging"
echo ""

if ask_yes_no "Create shell aliases?" "y"; then
    CREATE_ALIASES="true"
    print_success "Shell aliases will be created"
else
    CREATE_ALIASES="false"
    print_success "Skipping alias creation"
fi

# Step 9: Confirmation
print_header "Step 9: Installation Summary"
echo "Please review your configuration:"
echo ""
echo "  Script Directory:     $SCRIPT_DIR"
echo "  Log Directory:        $LOG_DIR"
echo "  Config Directory:     $CONFIG_DIR"
echo "  Plex Server:          $PLEX_SERVER"
echo "  Plex Token:           [HIDDEN]"
echo "  Check Interval:       $CHECK_INTERVAL seconds ($((CHECK_INTERVAL / 60)) minutes)"
if [[ "$MAX_WAIT_TIME_ENABLED" == "true" ]]; then
    echo "  Max Wait Time:        Enabled ($MAX_WAIT_TIME seconds / $((MAX_WAIT_TIME / 60)) minutes)"
else
    echo "  Max Wait Time:        Disabled (infinite wait)"
fi
echo "  Timer Schedule:       $TIMER_SCHEDULE"
echo "  Timer Persistent:     $TIMER_PERSISTENT"
echo "  Log Rotation:         $LOG_FILE_ROLLOVER ($LOG_FILE_ROLLOVER_DAYS days)"
echo "  Debug Mode:           $DEBUG"
echo "  Create Aliases:       $CREATE_ALIASES"
echo ""

if ! ask_yes_no "Proceed with installation?" "y"; then
    print_warning "Installation cancelled by user"
    exit 0
fi

# Step 10: Create directories
print_header "Step 10: Creating Directories"

print_info "Creating script directory..."
if mkdir -p "$SCRIPT_DIR/scripts/plex-safe-reboot" 2>/dev/null; then
    print_success "Script directory created: $SCRIPT_DIR/scripts/plex-safe-reboot"
else
    print_error "Failed to create script directory"
    exit 1
fi

print_info "Creating log directory..."
if mkdir -p "$LOG_DIR" 2>/dev/null; then
    print_success "Log directory created: $LOG_DIR"
else
    print_error "Failed to create log directory"
    exit 1
fi

print_info "Creating config directory..."
if mkdir -p "$CONFIG_DIR" 2>/dev/null; then
    print_success "Config directory created: $CONFIG_DIR"
else
    print_error "Failed to create config directory"
    exit 1
fi

# Step 11: Install script
print_header "Step 11: Installing Script"

print_info "Copying script file..."
if cp plex-safe-reboot.sh "$SCRIPT_DIR/scripts/plex-safe-reboot/"; then
    chmod +x "$SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh"
    print_success "Script installed and made executable"
else
    print_error "Failed to copy script file"
    exit 1
fi

# Step 12: Create configuration file
print_header "Step 12: Creating Configuration File"

print_info "Generating configuration file..."

cat > "$CONFIG_DIR/config" <<EOF
# Configuration file for Plex Safe Reboot Service
# Generated by install.sh on $(date)
# After editing, ensure proper permissions: chmod 600 $CONFIG_DIR/config

# ============================================================================
# REQUIRED SETTINGS
# ============================================================================

# Plex authentication token
PLEX_TOKEN="$PLEX_TOKEN"

# ============================================================================
# PLEX SERVER SETTINGS
# ============================================================================

# Plex server URL
PLEX_SERVER="$PLEX_SERVER"

# ============================================================================
# TIMING SETTINGS
# ============================================================================

# Check interval in seconds (how often to check for active streams)
CHECK_INTERVAL=$CHECK_INTERVAL

# Maximum wait time in seconds (how long to wait before forcing reboot)
MAX_WAIT_TIME=$MAX_WAIT_TIME

# Enable or disable maximum wait time
# true = Reboot after MAX_WAIT_TIME even if streams are active
# false = Wait indefinitely until no streams are detected
MAX_WAIT_TIME_ENABLED=$MAX_WAIT_TIME_ENABLED

# ============================================================================
# LOGGING SETTINGS
# ============================================================================

# Log file location
LOGFILE="$LOG_DIR/plex-reboot.log"

# Debug mode - set to true to enable detailed logging
DEBUG=$DEBUG

# Log file rollover - automatically rotate and clean old log files
LOG_FILE_ROLLOVER=$LOG_FILE_ROLLOVER

# Log file rollover days - delete log files older than this many days
LOG_FILE_ROLLOVER_DAYS=$LOG_FILE_ROLLOVER_DAYS

# ============================================================================
# SCRIPT SETTINGS
# ============================================================================

# Script directory (where the script is installed)
SCRIPT_DIR="$SCRIPT_DIR/scripts/plex-safe-reboot"

# ============================================================================
# OPERATIONAL SETTINGS
# ============================================================================

# Force reboot - skip stream check and reboot immediately
# WARNING: Setting this to true will reboot without checking for streams!
FORCE_REBOOT=false

# Dry run mode - show what would happen without actually rebooting
# Set to true for testing
DRY_RUN=false
EOF

if [[ -f "$CONFIG_DIR/config" ]]; then
    chmod 600 "$CONFIG_DIR/config"
    print_success "Configuration file created and secured: $CONFIG_DIR/config"
else
    print_error "Failed to create configuration file"
    exit 1
fi

# Step 13: Install systemd files
print_header "Step 13: Installing Systemd Service and Timer"

print_info "Updating systemd service file with custom paths..."

# Update service file with custom paths
sed "s|/usr/local/bin/scripts/plex-safe-reboot|$SCRIPT_DIR/scripts/plex-safe-reboot|g" plex-safe-reboot.service > /tmp/plex-safe-reboot.service.tmp
sed -i "s|/var/log/plex-safe-reboot|$LOG_DIR|g" /tmp/plex-safe-reboot.service.tmp
sed -i "s|/etc/plex-safe-reboot/config|$CONFIG_DIR/config|g" /tmp/plex-safe-reboot.service.tmp

print_info "Installing systemd service..."
if cp /tmp/plex-safe-reboot.service.tmp /etc/systemd/system/plex-safe-reboot.service; then
    chmod 644 /etc/systemd/system/plex-safe-reboot.service
    print_success "Systemd service installed"
else
    print_error "Failed to install systemd service"
    exit 1
fi

print_info "Creating systemd timer with custom schedule..."

# Create timer with Persistent=false initially to prevent immediate execution
# It will be updated to user's choice when they enable the timer
cat > /etc/systemd/system/plex-safe-reboot.timer <<EOF
[Unit]
Description=Plex Safe Reboot Timer
Documentation=https://github.com/yourusername/plex-safe-reboot
Requires=plex-safe-reboot.service

[Timer]
# Schedule: $TIMER_SCHEDULE
OnCalendar=$TIMER_SCHEDULE

# Persistent mode disabled during installation to prevent immediate execution
# Will be set to $TIMER_PERSISTENT when timer is enabled
Persistent=false

# Randomize start time by up to 15 minutes to avoid exact timing
RandomizedDelaySec=15min

[Install]
WantedBy=timers.target
EOF

if [[ -f /etc/systemd/system/plex-safe-reboot.timer ]]; then
    chmod 644 /etc/systemd/system/plex-safe-reboot.timer
    print_success "Systemd timer installed with schedule: $TIMER_SCHEDULE"
else
    print_error "Failed to install systemd timer"
    exit 1
fi

rm -f /tmp/plex-safe-reboot.service.tmp

# Step 14: Create aliases if requested
if [[ "$CREATE_ALIASES" == "true" ]]; then
    print_header "Step 14: Creating Shell Aliases"
    
    ALIAS_FILE="/etc/profile.d/plex-safe-reboot-aliases.sh"
    
    print_info "Creating alias file..."
    
    cat > "$ALIAS_FILE" <<EOF
# Plex Safe Reboot aliases
# Generated by install.sh on $(date)

alias plex-safe-reboot='sudo $SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh'
alias plex-safe-reboot-config='sudo $SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh --config'
alias plex-safe-reboot-dry-run='sudo $SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh --dry-run'
alias plex-safe-reboot-debug='sudo $SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh --debug'
EOF
    
    chmod 644 "$ALIAS_FILE"
    print_success "Aliases created in: $ALIAS_FILE"
    print_info "Aliases will be available in new shell sessions"
    print_info "To use them now, run: source $ALIAS_FILE"
fi

# Step 15: Set permissions
print_header "Step 15: Setting Permissions"

print_info "Setting ownership and permissions..."
chown -R root:root "$SCRIPT_DIR/scripts/plex-safe-reboot"
chown -R root:root "$CONFIG_DIR"
chown -R root:root "$LOG_DIR"
print_success "Permissions set"

# Step 16: Reload systemd
print_header "Step 16: Reloading Systemd"

print_info "Reloading systemd daemon..."
if systemctl daemon-reload; then
    print_success "Systemd daemon reloaded"
else
    print_error "Failed to reload systemd daemon"
    exit 1
fi

# Step 17: Timer Setup (deferred to after testing)
print_header "Step 17: Timer Setup"

print_info "Timer installation complete but not yet enabled"
print_info "The timer will be enabled after testing to prevent accidental reboots"

# Step 18: Test configuration
print_header "Step 18: Test Configuration"

echo ""
TEST_PASSED=false
if ask_yes_no "Run a test (dry-run) now to verify configuration?" "y"; then
    print_info "Running test (dry-run mode)..."
    print_warning "This will NOT actually reboot the system - it's just a test!"
    echo ""
    
    # Run the script directly with --dry-run flag (safer than using systemctl)
    if "$SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh" --dry-run; then
        echo ""
        print_success "Test completed successfully!"
        print_info "The script verified it can connect to Plex and check for streams."
        TEST_PASSED=true
    else
        echo ""
        print_error "Test failed. Please check the output above for errors."
        print_warning "Common issues:"
        echo "  • Plex server not accessible at $PLEX_SERVER"
        echo "  • Invalid Plex token"
        echo "  • Network connectivity issues"
        echo ""
        print_info "You can review the configuration:"
        echo "  Config: $CONFIG_DIR/config"
        echo "  Edit: sudo nano $CONFIG_DIR/config"
    fi
else
    print_warning "Skipping test. You should test manually before enabling the timer."
fi

# Step 19: Enable Timer (only after successful test or user confirmation)
print_header "Step 19: Enable Timer"

if [[ "$TEST_PASSED" == true ]]; then
    echo ""
    print_warning "═══════════════════════════════════════════════════════════════"
    print_warning "                    REBOOT WARNING"
    print_warning "═══════════════════════════════════════════════════════════════"
    echo ""
    print_warning "Enabling the timer will activate automatic reboots:"
    echo "  • Schedule: $TIMER_SCHEDULE"
    echo "  • Persistent: $TIMER_PERSISTENT"
    echo ""
    print_warning "The timer will wait for the scheduled time, then:"
    echo "  1. Check for active Plex streams"
    echo "  2. If no streams: REBOOT immediately"
    echo "  3. If streams active: Wait up to max wait time, then REBOOT"
    echo ""
    print_warning "The system will NOT reboot immediately upon enabling."
    print_warning "It will wait for the next scheduled time: $TIMER_SCHEDULE"
    echo ""
    print_warning "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if ask_yes_no "Do you want to enable the timer NOW?" "n"; then
        # Update timer file with user's Persistent choice before enabling
        print_info "Updating timer configuration..."
        sed -i "s/^Persistent=.*/Persistent=$TIMER_PERSISTENT/" /etc/systemd/system/plex-safe-reboot.timer
        systemctl daemon-reload
        
        # Check when the timer would run
        print_info "Checking timer schedule..."
        echo ""
        print_warning "IMPORTANT: Verify the next run time before proceeding!"
        
        # Enable but don't start yet
        print_info "Enabling timer (will start on boot)..."
        if systemctl enable plex-safe-reboot.timer; then
            print_success "Timer enabled"
        else
            print_error "Failed to enable timer"
        fi
        
        # Show when it would run if we start it
        print_info "If started now, the timer would run at:"
        systemd-analyze calendar "$TIMER_SCHEDULE" 2>/dev/null | head -5 || echo "  (Unable to calculate - check manually)"
        echo ""
        
        print_warning "═══════════════════════════════════════════════════════════════"
        print_warning "FINAL CONFIRMATION: Starting the timer now"
        print_warning "═══════════════════════════════════════════════════════════════"
        echo ""
        
        if ask_yes_no "Start the timer NOW? (System will reboot at next scheduled time)" "n"; then
            print_info "Starting timer..."
            if systemctl start plex-safe-reboot.timer; then
                print_success "Timer started"
                echo ""
                print_info "Next scheduled run:"
                systemctl list-timers plex-safe-reboot.timer --no-pager | grep plex-safe-reboot || true
                echo ""
                print_info "To stop the timer: sudo systemctl stop plex-safe-reboot.timer"
            else
                print_error "Failed to start timer"
            fi
        else
            print_info "Timer enabled but not started."
            print_info "Start it later with: sudo systemctl start plex-safe-reboot.timer"
        fi
    else
        print_info "Timer not enabled. You can enable it later when ready:"
        echo "  sudo systemctl enable plex-safe-reboot.timer"
        echo "  sudo systemctl start plex-safe-reboot.timer"
    fi
else
    print_warning "Timer not enabled due to failed/skipped test"
    print_info "After fixing any issues, enable the timer with:"
    echo "  sudo systemctl enable plex-safe-reboot.timer"
    echo "  sudo systemctl start plex-safe-reboot.timer"
fi

# Step 20: Configure update.sh
print_header "Step 20: Configuring Update Script"

CURRENT_DIR="$(pwd)"
if [[ -f "$CURRENT_DIR/update.sh" ]]; then
    print_info "Configuring update.sh with installation paths..."
    
    # Create configured update.sh
    sed "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" "$CURRENT_DIR/update.sh" > /tmp/update.sh.tmp
    sed -i "s|__LOG_DIR__|$LOG_DIR|g" /tmp/update.sh.tmp
    sed -i "s|__CONFIG_DIR__|$CONFIG_DIR|g" /tmp/update.sh.tmp
    
    # Copy to same directory as install.sh
    cp /tmp/update.sh.tmp "$CURRENT_DIR/update.sh"
    chmod +x "$CURRENT_DIR/update.sh"
    rm /tmp/update.sh.tmp
    
    print_success "Update script configured: $CURRENT_DIR/update.sh"
else
    print_warning "update.sh not found in current directory - skipping configuration"
fi

# Installation complete
print_header "Installation Complete!"

print_success "Plex Safe Reboot Service has been successfully installed!"
echo ""
echo "Configuration Summary:"
echo "  • Script:     $SCRIPT_DIR/scripts/plex-safe-reboot/plex-safe-reboot.sh"
echo "  • Config:     $CONFIG_DIR/config"
echo "  • Logs:       $LOG_DIR/plex-reboot.log"
echo "  • Service:    /etc/systemd/system/plex-safe-reboot.service"
echo "  • Timer:      /etc/systemd/system/plex-safe-reboot.timer"
if [[ "$CREATE_ALIASES" == "true" ]]; then
    echo "  • Aliases:    $ALIAS_FILE"
fi
echo ""
echo "Timer Schedule:"
echo "  • When:       $TIMER_SCHEDULE"
echo "  • Persistent: $TIMER_PERSISTENT"
echo ""
echo "Useful Commands:"
echo "  • Check timer status:    sudo systemctl status plex-safe-reboot.timer"
echo "  • View next run:         sudo systemctl list-timers plex-safe-reboot.timer"
echo "  • View logs:             sudo journalctl -u plex-safe-reboot.service -f"
echo "  • Edit config:           sudo nano $CONFIG_DIR/config"
echo "  • Run manually:          sudo systemctl start plex-safe-reboot.service"
echo ""

if [[ "$CREATE_ALIASES" == "true" ]]; then
    echo "Shell Aliases (available after sourcing or in new shells):"
    echo "  • plex-safe-reboot              - Run the script"
    echo "  • plex-safe-reboot-config       - Edit configuration"
    echo "  • plex-safe-reboot-dry-run      - Test without rebooting"
    echo "  • plex-safe-reboot-debug        - Run with debug logging"
    echo ""
    echo "To use aliases now: source $ALIAS_FILE"
    echo ""
fi

echo "Update Configuration:"
echo "  • To update settings: sudo ./update.sh"
echo "  • To reinstall:       sudo ./install.sh"
echo ""

print_info "For more information, see README.md and QUICKSTART.md"
echo ""
print_success "Thank you for using Plex Safe Reboot!"
