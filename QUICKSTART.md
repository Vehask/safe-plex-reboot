# Plex Safe Reboot - Quick Start Guide

## Installation (One-Time Setup)

### Interactive Installation (Recommended)

```bash
# Run the interactive installer - it will guide you through everything!
sudo ./install.sh
```

The installer will ask you about:
- Installation directories (script and logs)
- Plex server location (localhost or network IP)
- Your Plex token
- Timing settings (check interval, max wait time enable/disable)
- Timer schedule (daily or specific days/time)
- Log rotation settings
- Shell aliases creation
- And more!

### Manual Installation

```bash
# 1. Run the installation script
sudo ./install.sh

# 2. Edit the configuration file (if needed)
sudo nano /etc/plex-safe-reboot/config

# 3. Set your PLEX_TOKEN (required!)
# Get from: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/

# 4. If Plex is on a different machine, update PLEX_SERVER
# Example: PLEX_SERVER="http://YOUR_PLEX_SERVER_IP:32400"

# 5. Enable and start the timer
sudo systemctl enable plex-safe-reboot.timer
sudo systemctl start plex-safe-reboot.timer
```

## Common Commands

### Check Status
```bash
# Check if timer is running
sudo systemctl status plex-safe-reboot.timer

# View next scheduled run
sudo systemctl list-timers plex-safe-reboot.timer

# Check last service run
sudo systemctl status plex-safe-reboot.service
```

### View Logs
```bash
# View recent logs
sudo journalctl -u plex-safe-reboot.service -n 50

# Follow logs in real-time
sudo journalctl -u plex-safe-reboot.service -f

# View log file
sudo tail -f /var/log/plex-safe-reboot/plex-reboot.log
```

### Manual Operations
```bash
# Run service manually now
sudo systemctl start plex-safe-reboot.service

# Test without rebooting (edit config first: DRY_RUN=true)
sudo systemctl start plex-safe-reboot.service

# Stop the timer
sudo systemctl stop plex-safe-reboot.timer

# Restart the timer
sudo systemctl restart plex-safe-reboot.timer
```

### Configuration Changes
```bash
# Edit configuration
sudo nano /etc/plex-safe-reboot/config

# After editing, test the changes
sudo systemctl start plex-safe-reboot.service

# Watch the logs to verify
sudo journalctl -u plex-safe-reboot.service -f
```

### Change Schedule
```bash
# Edit timer schedule
sudo nano /etc/systemd/system/plex-safe-reboot.timer

# Reload systemd after changes
sudo systemctl daemon-reload
sudo systemctl restart plex-safe-reboot.timer
```

## Configuration Quick Reference

### For Local Plex Server (Same Machine)
```bash
PLEX_TOKEN="your_token_here"
PLEX_SERVER="http://127.0.0.1:32400"
```

### For Network Plex Server (CT/LXC Container)
```bash
PLEX_TOKEN="your_token_here"
PLEX_SERVER="http://YOUR_PLEX_SERVER_IP:32400"
```

### Enable Debug Mode
```bash
DEBUG=true
```

### Test Mode (No Actual Reboot)
```bash
DRY_RUN=true
DEBUG=true
```

### Infinite Wait Mode (No Maximum Wait Time)
```bash
# Wait indefinitely for streams to end
MAX_WAIT_TIME_ENABLED=false
```

### Enable Log Rotation
```bash
LOG_FILE_ROLLOVER=true
LOG_FILE_ROLLOVER_DAYS=30  # Keep logs for 30 days
```

## Shell Aliases (If Configured)

If you enabled aliases during installation:

```bash
# Run the script
plex-safe-reboot

# Edit configuration
plex-safe-reboot-config

# Test without rebooting
plex-safe-reboot-dry-run

# Run with debug logging
plex-safe-reboot-debug
```

## Command-Line Flags

The script supports these flags:

```bash
# Test mode (no actual reboot)
sudo /path/to/plex-safe-reboot.sh --dry-run

# Debug mode (detailed logging)
sudo /path/to/plex-safe-reboot.sh --debug

# Edit configuration (opens in nano)
sudo /path/to/plex-safe-reboot.sh --config

# Show help
/path/to/plex-safe-reboot.sh --help
```

## Troubleshooting

### Service Won't Start
```bash
# Check for errors
sudo journalctl -u plex-safe-reboot.service -n 100

# Test configuration
sudo /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh
```

### Can't Connect to Plex
```bash
# Test connectivity
curl -I http://127.0.0.1:32400
# or
curl -I http://YOUR_PLEX_SERVER_IP:32400

# Enable debug mode in config
DEBUG=true
```

### Timer Not Running
```bash
# Check if enabled
sudo systemctl is-enabled plex-safe-reboot.timer

# Enable if needed
sudo systemctl enable plex-safe-reboot.timer
sudo systemctl start plex-safe-reboot.timer
```

## Default Schedule

**Weekly on Sunday at 3:00 AM** (with 15-minute random delay)

To change, edit `/etc/systemd/system/plex-safe-reboot.timer`

## Important Files

| File | Purpose |
|------|---------|
| `/etc/plex-safe-reboot/config` | Configuration file |
| `/usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh` | Main script |
| `/etc/systemd/system/plex-safe-reboot.service` | Systemd service |
| `/etc/systemd/system/plex-safe-reboot.timer` | Systemd timer |
| `/var/log/plex-safe-reboot/plex-reboot.log` | Log file |

## Getting Your Plex Token

1. Sign in to your Plex account in Plex Web App
2. Browse to a library item and view the XML for it
3. Look in the URL and find the token as the X-Plex-Token value
4. Copy the token and paste it into `/etc/plex-safe-reboot/config`

More info: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/

## Security Note

The config file contains your Plex token - keep it secure!
```bash
sudo chmod 600 /etc/plex-safe-reboot/config
```
