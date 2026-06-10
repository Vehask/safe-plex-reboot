# Plex Safe Reboot

A systemd service that safely reboots your system only when Plex Media Server has no active streams. Perfect for scheduled maintenance reboots without interrupting users.

## Features

- ✅ Checks for active Plex streams before rebooting
- ✅ Configurable check intervals and maximum wait times
- ✅ Optional infinite wait mode (wait indefinitely for streams to end)
- ✅ Automatic log rotation and cleanup
- ✅ Runs as a systemd service with timer support
- ✅ Interactive installation wizard
- ✅ Comprehensive logging with optional debug mode
- ✅ Dry-run mode for testing
- ✅ Force reboot option for emergencies
- ✅ Automatic retry on connection failures

## Requirements

- Linux system with systemd
- Plex Media Server (local or network accessible)
- `curl` command-line tool
- Root/sudo access for installation

## Installation

### Quick Installation (Recommended)

Use the interactive installation wizard:

```bash
sudo ./install.sh
```

The installer will guide you through:
- ✅ Choosing installation directories
- ✅ Configuring Plex server connection (localhost or network IP)
- ✅ Setting up your Plex token
- ✅ Configuring timing options (check interval, max wait time)
- ✅ Customizing timer schedule (daily or specific days/time)
- ✅ Setting up log rotation
- ✅ Creating convenient shell aliases
- ✅ Testing the configuration
- ✅ Enabling the systemd timer

### Manual Installation

If you prefer manual installation:

#### 1. Create Required Directories

```bash
sudo mkdir -p /usr/local/bin/scripts/plex-safe-reboot
sudo mkdir -p /etc/plex-safe-reboot
sudo mkdir -p /var/log/plex-safe-reboot
```

#### 2. Install the Script

```bash
sudo cp plex-safe-reboot.sh /usr/local/bin/scripts/plex-safe-reboot/
sudo chmod +x /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh
```

#### 3. Install Systemd Files

```bash
sudo cp plex-safe-reboot.service /etc/systemd/system/
sudo cp plex-safe-reboot.timer /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/plex-safe-reboot.service
sudo chmod 644 /etc/systemd/system/plex-safe-reboot.timer
```

#### 4. Configure the Service

```bash
# Copy the example configuration
sudo cp config.example /etc/plex-safe-reboot/config

# Edit the configuration file
sudo nano /etc/plex-safe-reboot/config
```

**Important:** You must set your `PLEX_TOKEN` in the configuration file. Get your token from:
https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/

```bash
# Secure the configuration file (contains sensitive token)
sudo chmod 600 /etc/plex-safe-reboot/config
```

#### 5. Set Proper Permissions

```bash
sudo chown -R root:root /usr/local/bin/scripts/plex-safe-reboot
sudo chown -R root:root /etc/plex-safe-reboot
sudo chown -R root:root /var/log/plex-safe-reboot
```

#### 6. Reload Systemd and Enable the Timer

```bash
# Reload systemd to recognize new service files
sudo systemctl daemon-reload

# Enable the timer to start on boot
sudo systemctl enable plex-safe-reboot.timer

# Start the timer
sudo systemctl start plex-safe-reboot.timer
```

## Configuration

Edit [`/etc/plex-safe-reboot/config`](file:///etc/plex-safe-reboot/config) to customize the service:

### Required Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `PLEX_TOKEN` | Your Plex authentication token (REQUIRED) | `"abc123xyz..."` |

### Optional Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `PLEX_SERVER` | Plex server URL | `http://127.0.0.1:32400` |
| `CHECK_INTERVAL` | Seconds between stream checks | `300` (5 min) |
| `MAX_WAIT_TIME` | Maximum seconds to wait before forcing reboot | `7200` (2 hours) |
| `MAX_WAIT_TIME_ENABLED` | Enable/disable maximum wait time limit | `true` |
| `LOGFILE` | Path to log file | `/var/log/plex-safe-reboot/plex-reboot.log` |
| `LOG_FILE_ROLLOVER` | Enable automatic log rotation | `true` |
| `LOG_FILE_ROLLOVER_DAYS` | Days to keep old log files | `30` |
| `DEBUG` | Enable detailed logging | `false` |
| `FORCE_REBOOT` | Skip stream check and reboot immediately | `false` |
| `DRY_RUN` | Test mode - don't actually reboot | `false` |
| `SCRIPT_DIR` | Script installation directory | `/usr/local/bin/scripts/plex-safe-reboot` |

### Example Configuration for CT/LXC Container

If your Plex server runs in a container on your local network:

```bash
PLEX_TOKEN="your_actual_token_here"
PLEX_SERVER="http://YOUR_PLEX_SERVER_IP:32400"
CHECK_INTERVAL=300
MAX_WAIT_TIME=7200
MAX_WAIT_TIME_ENABLED=true
LOG_FILE_ROLLOVER=true
LOG_FILE_ROLLOVER_DAYS=30
DEBUG=false
```

### Infinite Wait Mode

To wait indefinitely for streams to end (no maximum wait time):

```bash
MAX_WAIT_TIME_ENABLED=false
```

When disabled, the script will keep checking for active streams at the configured interval and only reboot when no streams are detected.

## Usage

### Timer-Based Execution (Recommended)

The timer runs automatically on a schedule (default: Sunday at 3:00 AM).

```bash
# Check timer status
sudo systemctl status plex-safe-reboot.timer

# View next scheduled run
sudo systemctl list-timers plex-safe-reboot.timer

# Stop the timer
sudo systemctl stop plex-safe-reboot.timer

# Disable the timer (prevent auto-start on boot)
sudo systemctl disable plex-safe-reboot.timer
```

### Manual Execution

Run the service manually at any time:

```bash
# Run the service now
sudo systemctl start plex-safe-reboot.service

# Check service status
sudo systemctl status plex-safe-reboot.service
```

### Direct Script Execution

You can also run the script directly with command-line flags:

```bash
# Normal run
sudo /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh

# Dry run (test without rebooting)
sudo /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh --dry-run

# Enable debug logging
sudo /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh --debug

# Edit configuration file (opens in nano)
sudo /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh --config

# Show help
/usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh --help
```

### Using Shell Aliases (If Configured During Installation)

If you enabled aliases during installation, you can use these convenient shortcuts:

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

Aliases are stored in `/etc/profile.d/plex-safe-reboot-aliases.sh` and are available in new shell sessions.

## Customizing the Timer Schedule

Edit [`/etc/systemd/system/plex-safe-reboot.timer`](file:///etc/systemd/system/plex-safe-reboot.timer) to change when the service runs:

```ini
# Weekly on Sunday at 3:00 AM (default)
OnCalendar=Sun *-*-* 03:00:00

# Daily at 4:00 AM
OnCalendar=*-*-* 04:00:00

# First day of every month at 2:00 AM
OnCalendar=*-*-01 02:00:00

# Every Monday and Friday at 3:30 AM
OnCalendar=Mon,Fri *-*-* 03:30:00
```

After editing, reload systemd:

```bash
sudo systemctl daemon-reload
sudo systemctl restart plex-safe-reboot.timer
```

## Monitoring and Logs

### View Logs

```bash
# View recent logs from systemd journal
sudo journalctl -u plex-safe-reboot.service -n 50

# Follow logs in real-time
sudo journalctl -u plex-safe-reboot.service -f

# View log file directly
sudo tail -f /var/log/plex-safe-reboot/plex-reboot.log

# View all logs for today
sudo journalctl -u plex-safe-reboot.service --since today
```

### Check Service Status

```bash
# Check if timer is active
sudo systemctl is-active plex-safe-reboot.timer

# Check if timer is enabled
sudo systemctl is-enabled plex-safe-reboot.timer

# View detailed timer information
sudo systemctl status plex-safe-reboot.timer

# View detailed service information
sudo systemctl status plex-safe-reboot.service
```

## How It Works

1. **Timer triggers** the service at the scheduled time
2. **Service starts** and loads configuration from [`/etc/plex-safe-reboot/config`](file:///etc/plex-safe-reboot/config)
3. **Validates** connection to Plex server
4. **Checks** for active streams every `CHECK_INTERVAL` seconds
5. **Waits** if streams are active, up to `MAX_WAIT_TIME`
6. **Reboots** when no streams are detected OR max wait time is reached
7. **Logs** all activity to journal and log file

## Troubleshooting

### Service fails to start

```bash
# Check for configuration errors
sudo /usr/local/bin/scripts/plex-safe-reboot/plex-safe-reboot.sh

# View detailed error messages
sudo journalctl -u plex-safe-reboot.service -n 100 --no-pager
```

### Cannot connect to Plex server

1. Verify `PLEX_SERVER` URL in [`/etc/plex-safe-reboot/config`](file:///etc/plex-safe-reboot/config)
2. Test connectivity: `curl -I http://127.0.0.1:32400`
3. Verify `PLEX_TOKEN` is correct
4. Enable debug mode: `DEBUG=true` in config

### Script doesn't reboot

1. Ensure script runs as root (systemd service does this automatically)
2. Check if `DRY_RUN=true` is set in config
3. Verify `FORCE_REBOOT` is not preventing normal operation
4. Check logs for stream detection issues

### Enable Debug Mode

Edit [`/etc/plex-safe-reboot/config`](file:///etc/plex-safe-reboot/config):

```bash
DEBUG=true
```

Then restart the service:

```bash
sudo systemctl restart plex-safe-reboot.service
```

## Testing

### Test Without Rebooting

1. Edit [`/etc/plex-safe-reboot/config`](file:///etc/plex-safe-reboot/config):
   ```bash
   DRY_RUN=true
   DEBUG=true
   ```

2. Run the service:
   ```bash
   sudo systemctl start plex-safe-reboot.service
   ```

3. Watch the logs:
   ```bash
   sudo journalctl -u plex-safe-reboot.service -f
   ```

4. Verify it detects streams correctly and would reboot when appropriate

5. Disable dry-run mode when satisfied:
   ```bash
   DRY_RUN=false
   ```

## Uninstallation

```bash
# Stop and disable the timer
sudo systemctl stop plex-safe-reboot.timer
sudo systemctl disable plex-safe-reboot.timer

# Remove systemd files
sudo rm /etc/systemd/system/plex-safe-reboot.service
sudo rm /etc/systemd/system/plex-safe-reboot.timer

# Remove script and configuration
sudo rm -rf /usr/local/bin/scripts/plex-safe-reboot
sudo rm -rf /etc/plex-safe-reboot

# Optionally remove logs
sudo rm -rf /var/log/plex-safe-reboot

# Reload systemd
sudo systemctl daemon-reload
```

## Security Considerations

- The configuration file contains your Plex token - keep it secure with `chmod 600`
- The service runs as root to perform system reboots
- Logs may contain sensitive information - restrict access appropriately
- Consider using `ProtectSystem=strict` in the service file (already configured)

## Migration from VM to CT/LXC

If you've migrated Plex from a VM to a container:

1. Update `PLEX_SERVER` in [`/etc/plex-safe-reboot/config`](file:///etc/plex-safe-reboot/config):
   ```bash
   # For local container
   PLEX_SERVER="http://127.0.0.1:32400"
   
   # For network-accessible container
   PLEX_SERVER="http://YOUR_PLEX_SERVER_IP:32400"
   ```

2. Verify connectivity:
   ```bash
   curl -I http://YOUR_PLEX_SERVER_IP:32400
   ```

3. Test the configuration:
   ```bash
   sudo DRY_RUN=true DEBUG=true systemctl start plex-safe-reboot.service
   ```

## License

This project is provided as-is for personal and commercial use.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Support

For issues, questions, or suggestions, please open an issue on the project repository.
