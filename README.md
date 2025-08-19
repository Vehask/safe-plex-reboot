# Safe Plex Reboot Script

A bash script that safely reboots a server by checking for active Plex streams first. The script will postpone rebooting until all Plex streams have ended, ensuring users aren't interrupted during playback.

## Features

- ✅ **Stream Detection**: Monitors Plex API for active video streams
- ✅ **Automatic Postponing**: Waits until all streams finish before rebooting
- ✅ **Cross-VM Support**: Can run on different VM than Plex server
- ✅ **Cron Compatible**: Designed to work reliably in cron environments
- ✅ **Configurable Timeouts**: Maximum wait time to prevent infinite delays
- ✅ **Multiple Config Methods**: Environment variables, config files, or command line
- ✅ **Debug Mode**: Optional detailed logging for troubleshooting
- ✅ **Dry Run Mode**: Test functionality without actually rebooting

## Quick Start

### 1. Download the Script

```bash
# Clone the repository
git clone https://github.com/vehask/safe-plex-reboot.git
cd safe-plex-reboot

# Or download directly
wget https://raw.githubusercontent.com/vehask/safe-plex-reboot/main/safe-plex-reboot.sh
chmod +x safe-plex-reboot.sh
```
### 2. Make it executable
```bash
chmod +x /Path/to/script/safe-plex-reboot.sh
```

### 3. Get Your Plex Token

Follow this link for official instructions from Plex:
https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/

### 4. Configure the Script

```bash
# Copy the example configuration
cp plex-reboot.conf.example ~/.config/plex-reboot.conf

# Edit with your settings
nano ~/.config/plex-reboot.conf
```

**Basic configuration:**
```bash
# Your Plex authentication token
PLEX_TOKEN="your_actual_plex_token_here"

# Plex server URL
# Same VM/machine: http://127.0.0.1:32400
# Different VM: http://PLEX_VM_IP:32400
PLEX_SERVER="http://127.0.0.1:32400"
```

### 4. Test the Script

```bash
# Test without actually rebooting
./safe-plex-reboot.sh --dry-run

# Test with debug output
./safe-plex-reboot.sh --dry-run --debug
```

### 5. Set Up Automated Execution

**Cron Job**
```bash
# Edit root's crontab
sudo crontab -e
# OR
sudo nano /etc/crontab

# Add entry to reboot daily at 5 AM if no streams
0 5 * * * /full/path/to/safe-plex-reboot.sh
```

## Usage

```bash
./safe-plex-reboot.sh [OPTIONS]
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--force` | Skip stream check and reboot immediately |
| `--dry-run` | Show what would happen without rebooting |
| `--debug` | Enable detailed debug logging |
| `--help` | Show help message |

### Examples

```bash
# Normal operation - check streams and reboot if none active
./safe-plex-reboot.sh

# Force immediate reboot (ignore streams)
./safe-plex-reboot.sh --force

# Test mode with debug output
./safe-plex-reboot.sh --dry-run --debug

# Run with environment variable
PLEX_TOKEN="your_token" ./safe-plex-reboot.sh
```

## Configuration

### Configuration Methods (in order of priority)

1. **Command line options** (`--debug`, `--force`, etc.)
2. **Environment variables** (`PLEX_TOKEN`, `DEBUG`, etc.)
3. **Configuration files** (checked in this order):
   - `~/.config/plex-reboot.conf`
   - `./plex-reboot.conf` (same directory as script)
   - `/etc/plex-reboot.conf`
   - `~/.plex-reboot.conf`

### Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `PLEX_TOKEN` | *required* | Plex authentication token |
| `PLEX_SERVER` | `http://127.0.0.1:32400` | Plex server URL |
| `LOGFILE` | `/var/log/update-logs/update.log` | Log file location |
| `CHECK_INTERVAL` | `300` | Seconds between stream checks (5 min) |
| `MAX_WAIT_TIME` | `7200` | Maximum wait time in seconds (2 hours) |
| `DEBUG` | `false` | Enable debug logging |

### Example Configuration File

```bash
# Plex authentication token (required)
PLEX_TOKEN="your_actual_plex_token_here"

# Plex server (adjust for your setup)
PLEX_SERVER="http://192.168.1.100:32400"

# Optional settings
LOGFILE="/var/log/plex-reboot.log"
CHECK_INTERVAL=300
MAX_WAIT_TIME=7200
DEBUG=false
```

## Cross-VM Setup

If running the script on a different VM than your Plex server:

### 1. Find Plex VM IP
```bash
# On Plex VM, run:
hostname -I
```

### 2. Update Configuration
```bash
# Set Plex server to VM's IP
PLEX_SERVER="http://192.168.1.100:32400"
```

### 3. Test Connectivity
```bash
# From the VM running the script:
curl -I "http://192.168.1.100:32400"
curl -sf "http://192.168.1.100:32400/?X-Plex-Token=YOUR_TOKEN"
```

### 4. Firewall Setup
```bash
# On Plex VM, allow connections from other VMs:
sudo ufw allow from 192.168.1.0/24 to any port 32400
```

## Troubleshooting

### Common Issues

**Script runs but doesn't reboot when streams = 0**
- Enable debug mode: `--debug`
- Check logs for API response issues
- Verify Plex token is valid

**"Cannot connect to Plex server"**
- Check `PLEX_SERVER` URL is correct
- Test connectivity: `curl -I "http://your-plex-server:32400"`
- Verify firewall settings

**Works manually but not in cron**
- Use absolute paths in cron: `/full/path/to/safe-plex-reboot.sh`
- Set environment in cron: `PLEX_TOKEN=token /path/to/script`
- Check cron logs: `sudo tail -f /var/log/cron`

**Cron doesn't have required commands**
- Script automatically finds commands in standard locations
- Install missing packages: `apt install curl` or `yum install curl`

### Debug Mode

Enable detailed logging to troubleshoot issues:

```bash
# Command line
./safe-plex-reboot.sh --debug

# Environment variable
DEBUG=true ./safe-plex-reboot.sh

# Configuration file
echo "DEBUG=true" >> ~/.config/plex-reboot.conf
```

### Check Cron Environment

Create a test script to see what cron can access:
```bash
#!/bin/bash
echo "PATH: $PATH" > /tmp/cron-test.log
echo "HOME: $HOME" >> /tmp/cron-test.log
which curl >> /tmp/cron-test.log 2>&1
which systemctl >> /tmp/cron-test.log 2>&1
```

## Requirements

- **Bash 4.0+**
- **curl** (for API calls)
- **Root access** (for reboot capability)
- **Network access** to Plex server
- **Valid Plex token**

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

If you encounter issues:

1. **Enable debug mode** and check the logs
2. **Test manually** before setting up automation
3. **Verify network connectivity** to Plex server
4. **Check the troubleshooting section** above
5. **Open an issue** with debug logs and configuration details
