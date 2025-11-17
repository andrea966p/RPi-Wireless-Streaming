# Wireless KVM Lab System

## Reliable wireless KVM solution for scientific lab using Sunshine/Moonlight

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Prerequisites](#prerequisites)
- [Installation Guide](#installation-guide)
- [Configuration](#configuration)
- [Testing](#testing)
- [Operation](#operation)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Recovery Procedures](#recovery-procedures)

---

## Overview

This system provides wireless KVM (Keyboard, Video, Mouse) control between an Ubuntu PC and Raspberry Pi 4 Model B using Sunshine and Moonlight streaming technology. It's designed for scientific lab environments where stability and reliability are critical.

### Key Features

- ✅ Automatic connection with retry logic
- ✅ Watchdog monitoring for 24/7 reliability
- ✅ Comprehensive error logging
- ✅ Emergency recovery procedures
- ✅ High-performance operation on Pi 4 Model B
- ✅ Optimized for low-latency local network streaming

### Use Case

This system allows lab users to control an Ubuntu PC remotely through a Raspberry Pi 4 Model B, eliminating the need for additional displays, keyboards, and mice at the lab workstation. Perfect for equipment control, data acquisition, or remote monitoring scenarios.

---

## System Architecture

```text
┌──────────────────────────────────────────────────────────────┐
│                      Lab WiFi Network                        │
│                      192.168.0.0/24                          │
│                                                              │
│   ┌────────────────────────┐                                 │
│   │   Ubuntu PC            │                                 │
│   │   ┌──────────────┐     │                                 │
│   │   │  Sunshine    │     │  Video/Audio/Input Streaming    │
│   │   │  Server      │     │  ─────────────────────────────► │
│   │   └──────────────┘     │                                 │
│   │   ┌──────────────┐     │                                 │
│   │   │  Watchdog    │     │                                 │
│   │   └──────────────┘     │                                 │
│   │   192.168.0.56         │                                 │
│   │   andrea               │                                 │
│   └────────────────────────┘                                 │
│                                                              │
│   ┌────────────────────────┐                                 │
│   │   Pi 4 Model B         │                                 │
│   │   ┌──────────────┐     │                                 │
│   │   │  Moonlight   │     │                                 │
│   │   │  Client      │◄────┼────────────────────────────────┘
│   │   └──────────────┘     │
│   │   ┌──────────────┐     │
│   │   │  Auto-Retry  │     │
│   │   └──────────────┘     │
│   │   192.168.0.47         │
│   │   pi4hdmi              │
│   └────────────────────────┘
│
│   Connected to: Monitor, Keyboard, Mouse
│                 (Controls the Ubuntu PC)
└──────────────────────────────────────────────────────────────┘
```

### Component Roles

#### Ubuntu PC (Sunshine Server)

- Runs Sunshine streaming server
- Captures video/audio from desktop
- Processes input from Moonlight client
- Watchdog monitors and auto-restarts on failure
- Power management disabled for 24/7 operation

#### Raspberry Pi 4 Model B (Moonlight Client)

- Runs Moonlight streaming client
- Decodes and displays video stream (hardware accelerated)
- Sends keyboard/mouse input to PC
- Auto-retry logic for connection failures
- Excellent performance for high-quality streaming (1080p60 or 4K30)

---

## Prerequisites

### Hardware Requirements

#### Ubuntu PC

- **OS**: Ubuntu 20.04 LTS, 22.04 LTS, or 24.04 LTS (install script auto-detects version)
- **CPU**: Modern x86_64 CPU with hardware video encoding (Intel QSV, NVIDIA NVENC, or AMD VCE)
- **RAM**: 4GB minimum, 8GB+ recommended
- **GPU**: Integrated or discrete GPU with H.264 encoding support
- **Network**: Ethernet (preferred) or WiFi adapter
- **Storage**: 10GB free space

> **Note**: The installation script automatically detects your Ubuntu version and downloads the compatible Sunshine package.

#### Raspberry Pi 4 Model B

- **Model**: Raspberry Pi 4 Model B (quad-core 1.5GHz Cortex-A72)
- **RAM**: 1GB, 2GB, 4GB, or 8GB (any variant works, 2GB+ recommended)
- **Storage**: 16GB+ microSD card (Class 10 or better, U3/A1 recommended)
- **OS**: Raspberry Pi OS Lite or Desktop (64-bit recommended)
- **Power**: Quality 5V 3A USB-C power supply
- **Network**: Built-in WiFi (2.4GHz/5GHz) or Gigabit Ethernet (preferred)
- **Peripherals**: HDMI monitor (supports dual 4K displays), USB keyboard/mouse

### Network Requirements

- **Connection**: Both devices on same local network
- **Bandwidth**: 20+ Mbps for 1080p @ 60fps, 50+ Mbps for 4K @ 30fps
- **Latency**: < 20ms for good experience
- **WiFi**: 2.4GHz or 5GHz (Pi 4 supports both, 5GHz or Ethernet recommended)
- **Firewall**: Ability to configure firewall rules

### Software Prerequisites

Will be installed by setup scripts:

- Sunshine (PC)
- Moonlight (Pi 4)
- systemd (both)
- Various dependencies

---

## Installation Guide

> **Note:** All commands in this guide assume you start from the project root directory:
> ```bash
> cd ~/work/SKIM_Lab/RPi-Wireless-Streaming
> ```
> Adjust the path if your project is located elsewhere.

### Phase 1: Preparation

#### 1.1 Backup Current System

**On Ubuntu PC (from project root):**

```bash
cd wireless-kvm-lab/pc-side
sudo bash backup-config.sh
```

This creates a timestamped backup in `/var/backups/kvm-system/` containing:

- Network configuration
- Systemd services
- Power management settings
- Firewall rules
- Installed packages

#### 1.2 Verify Network Configuration

Review and update IP addresses in:

```bash
# From project root
cat wireless-kvm-lab/config/network-settings.md
```

Update these values for your network:

- PC IP address (currently: 192.168.0.56)
- Gateway address
- DNS servers

---

### Phase 2: PC Setup (Ubuntu)

#### 2.1 Install Sunshine

**From project root:**

```bash
cd wireless-kvm-lab/pc-side
sudo bash install-sunshine.sh
```

**What this does:**

- Installs Sunshine and all dependencies
- Configures udev rules for input devices
- Sets up firewall rules (if UFW enabled)
- Creates configuration directory
- Logs all actions to `/var/log/sunshine-install.log`

**Expected duration:** 5-10 minutes

#### 2.2 Configure Sunshine

After installation, access Sunshine web UI to complete setup:

1. Open browser on PC or another computer:
   
   ```text
   https://192.168.0.56:47990
   ```
   
   (Accept self-signed certificate)

2. Complete initial setup:
   - Set username/password
   - Configure video quality settings
   - Add "Desktop" as an application

3. (Optional) Copy template configuration:

   ```bash
   # From project root
   cp wireless-kvm-lab/config/sunshine-config.json ~/.config/sunshine/sunshine.conf
   # Edit as needed
   nano ~/.config/sunshine/sunshine.conf
   ```

#### 2.3 Disable Power Management

**CRITICAL for 24/7 operation (from pc-side directory or project root):**

```bash
# If still in pc-side from previous step:
sudo bash disable-power-management.sh

# Or from project root:
# cd wireless-kvm-lab/pc-side && sudo bash disable-power-management.sh
```

**What this does:**

- Disables sleep, suspend, hibernation
- Ignores lid close and power button
- Disables screen blanking
- Creates enforcement service for boot
- Logs to `/var/log/kvm-power-management.log`

**Reboot recommended** after this step.

#### 2.4 Install Systemd Services

**Note:** Sunshine can run as either a system service or user service. For lab use, user service is recommended as it has better display access.

**Option A: User Service (Recommended):**

```bash
# From project root
cd wireless-kvm-lab/pc-side

# Copy watchdog and status scripts
sudo cp sunshine-watchdog.service /etc/systemd/system/
sudo cp sunshine-watchdog.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/sunshine-watchdog.sh
sudo cp check-status.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-status.sh

# Reload systemd
sudo systemctl daemon-reload

# Enable user-level Sunshine (auto-starts on login)
systemctl --user enable sunshine
systemctl --user start sunshine

# Enable system-level watchdog
sudo systemctl enable sunshine-watchdog
sudo systemctl start sunshine-watchdog
```

**Option B: System Service (Alternative):**

```bash
# From project root
cd wireless-kvm-lab/pc-side

# Copy ALL service files including sunshine.service
sudo cp sunshine.service /etc/systemd/system/
sudo cp sunshine-watchdog.service /etc/systemd/system/
sudo cp sunshine-watchdog.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/sunshine-watchdog.sh
sudo cp check-status.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-status.sh

# NOTE: Update DISPLAY variable in sunshine.service to match your system
# Check your DISPLAY: echo $DISPLAY

# Reload systemd
sudo systemctl daemon-reload

# Enable and start services
sudo systemctl enable sunshine
sudo systemctl enable sunshine-watchdog
sudo systemctl start sunshine
sudo systemctl start sunshine-watchdog
```

#### 2.5 Verify PC Setup

```bash
# Check service status
sudo systemctl status sunshine
sudo systemctl status sunshine-watchdog

# Run comprehensive status check
bash /usr/local/bin/check-status.sh

# Verify ports are open
ss -tlnp | grep sunshine
```

**Expected output:**

- Sunshine service: active (running)
- Watchdog service: active (running)
- Ports 47984, 47989, 47990, 48010 listening
- Web UI accessible

---

### Phase 3: Pi 4 Setup

#### 3.1 Prepare Pi 4

1. **Flash Raspberry Pi OS:**
   - Download Raspberry Pi OS (64-bit recommended for Pi 4)
   - Use Raspberry Pi Imager
   - Configure WiFi and SSH in imager (advanced options)
   - Flash to microSD card

2. **Boot and initial setup:**
   
   ```bash
   # SSH into Pi (or use direct connection)
   ssh skimlab@pi4hdmi.local
   # Default password: raspberry (change immediately!)

   # Update system
   sudo apt update && sudo apt upgrade -y

   # Set hostname (optional)
   sudo hostnamectl set-hostname lab-kvm-pi
   ```

3. **Copy project files to Pi:**
   
   ```bash
   # From your development machine:
   scp -r wireless-kvm-lab skimlab@pi4hdmi.local:~/
   ```

#### 3.2 Install Moonlight

```bash
cd ~/wireless-kvm-lab/pi-side
sudo bash install-moonlight.sh
```

**What this does:**

- Installs Moonlight and dependencies
- Configures GPU memory allocation
- Optimizes network settings
- Tests connectivity to PC
- Configures auto-login (optional)
- Logs to `/var/log/moonlight-install.log`

**Expected duration:** 10-15 minutes

**IMPORTANT:** Reboot after installation for GPU changes:

```bash
sudo reboot
```

#### 3.3 Pair with Sunshine Server

After reboot:

```bash
# Verify network connectivity first
cd ~/wireless-kvm-lab/pi-side
bash network-check.sh

# Pair with PC
moonlight pair 192.168.0.56
```

**Follow the pairing process:**

1. Command will display a 4-digit PIN
2. Open Sunshine web UI on PC: `https://192.168.0.56:47990`
3. Go to "PIN" section
4. Enter the PIN displayed on Pi
5. Confirm pairing

**Verify pairing:**

```bash
moonlight list 192.168.0.56
# Should show "Desktop" application
```

#### 3.4 Test Connection Manually

Before enabling auto-start, test manually:

```bash
# IMPORTANT: Use explicit --resolution flag for proper quality
# DO NOT use --1080 shorthand (causes low quality 720p streaming)
moonlight-qt stream 192.168.0.56 "Desktop" \
    --resolution 1920x1080 \
    --fps 60 \
    --bitrate 20000 \
    --video-codec auto \
    --video-decoder auto
```

**Expected behavior:**

- Connection establishes within 5 seconds
- PC desktop displays on Pi's monitor at full 1080p quality
- Keyboard/mouse control PC seamlessly
- Smooth 60fps video with no stuttering
- Press Ctrl+Alt+Shift+Q to exit

**CRITICAL NOTE:** Using `--1080` instead of `--resolution 1920x1080` will result in only 720p quality! Always use the explicit resolution flag.

**If issues occur:** See [Troubleshooting](#troubleshooting) section

#### 3.5 Install Systemd Service

```bash
cd ~/wireless-kvm-lab/pi-side

# Copy service file and scripts
sudo cp moonlight-kvm.service /etc/systemd/system/
sudo cp start-moonlight.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/start-moonlight.sh

# Copy diagnostic scripts
sudo cp network-check.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/network-check.sh

# Reload systemd
sudo systemctl daemon-reload

# Enable service (will start on boot)
sudo systemctl enable moonlight-kvm

# Start service now
sudo systemctl start moonlight-kvm
```

#### 3.6 Verify Pi Setup

```bash
# Check service status
sudo systemctl status moonlight-kvm

# Check if Moonlight is running
ps aux | grep moonlight

# Run network diagnostics
bash /usr/local/bin/network-check.sh

# View logs
journalctl -u moonlight-kvm -f
```

---

### Phase 4: Recovery Tools Setup

Install emergency recovery scripts on both systems:

**On PC (from project root):**

```bash
cd wireless-kvm-lab/recovery
sudo cp emergency-restart-pc.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/emergency-restart-pc.sh
```

**On Pi:**

```bash
cd ~/wireless-kvm-lab/recovery
sudo cp emergency-restart-pi.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/emergency-restart-pi.sh
```

**Print troubleshooting card:**

```bash
# Print recovery/troubleshooting-card.md
# Keep physical copy near lab equipment
```

---

## Configuration

### Adjusting Video Quality

#### On PC (Sunshine)

Edit `~/.config/sunshine/sunshine.conf`:

```json
{
  "fps": [30, 60, 120],  // Pi 4 can handle high framerates
  "resolutions": [
    {"width": 1920, "height": 1080},  // Full HD
    {"width": 3840, "height": 2160}   // 4K (if needed)
  ],
  "bitrate": 20000  // Kbps - Pi 4 can handle higher bitrates
}
```

Restart Sunshine:

```bash
sudo systemctl restart sunshine
```

#### On Pi (Moonlight)

Video settings are in start script. Edit `/usr/local/bin/start-moonlight.sh`:

```bash
# Recommended settings for Pi 4:
VIDEO_WIDTH=1920      # Full HD
VIDEO_HEIGHT=1080
VIDEO_FPS=60          # Smooth 60fps (Pi 4 handles this easily)
VIDEO_BITRATE=20000   # High quality

# For 4K displays (recommended for 4GB+ Pi 4):
# VIDEO_WIDTH=3840
# VIDEO_HEIGHT=2160
# VIDEO_FPS=30
# VIDEO_BITRATE=50000
```

Restart Moonlight:

```bash
sudo systemctl restart moonlight-kvm
```

### Network Optimization

See `config/network-settings.md` for detailed network configuration.

**Quick tweaks:**

```bash
# Increase priority of Moonlight traffic (on PC)
sudo tc qdisc add dev eth0 root handle 1: prio
sudo tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip dst 192.168.0.100 flowid 1:1
```

### Changing IP Addresses

When moving to production environment:

1. Update `config/network-settings.md`
2. Update IP in all these files:
   - `pc-side/check-status.sh`
   - `pi-side/install-moonlight.sh`
   - `pi-side/start-moonlight.sh`
   - `pi-side/network-check.sh`
   - `recovery/emergency-restart-pi.sh`
   - `recovery/troubleshooting-card.md`

3. Configure static IPs (see network-settings.md)
4. Re-pair Moonlight with new IP
5. Test thoroughly

---

## Testing

### Test Checklist

#### Network Tests

```bash
# On Pi 4
bash /usr/local/bin/network-check.sh

# Should show:
# ✓ Network interface up
# ✓ IP address assigned
# ✓ Gateway reachable
# ✓ PC reachable
# ✓ Sunshine ports open
# ✓ Good latency (< 20ms)
```

#### Service Tests

```bash
# On PC
bash /usr/local/bin/check-status.sh

# On Pi
systemctl status moonlight-kvm
```

#### Functionality Tests

1. **Video quality:**
   - Smooth video playback
   - No stuttering or freezing
   - Acceptable latency (< 100ms)

2. **Input responsiveness:**
   - Keyboard inputs appear immediately
   - Mouse movement is smooth
   - No input lag

3. **Audio** (if enabled):
   - Audio plays clearly
   - Sync with video
   - No crackling or dropouts

4. **Stability:**
   - Connection stays active
   - No random disconnects
   - Automatic reconnection works

#### Stress Tests

```bash
# Test sustained connection
# Leave streaming for 4+ hours
# Monitor for disconnects or performance degradation

# Test recovery
# Manually kill Sunshine on PC
# Verify watchdog restarts it

# Test network interruption
# Temporarily disable WiFi on Pi
# Re-enable and verify auto-reconnect
```

---

## Operation

### Daily Operation

#### Starting the System

If auto-start is enabled (recommended), system starts automatically on boot:

1. Power on PC (if not already running 24/7)
2. Wait 2-3 minutes for PC to fully boot
3. Power on Pi 4
4. Wait 30-60 seconds for Pi to boot and connect
5. Desktop should appear on Pi's monitor

#### Manual Start

If auto-start is disabled:

**PC:**

```bash
sudo systemctl start sunshine
sudo systemctl start sunshine-watchdog
```

**Pi:**

```bash
sudo systemctl start moonlight-kvm
# Or manually:
moonlight stream 192.168.0.56 -app Desktop
```

#### Stopping the System

```bash
# On Pi
sudo systemctl stop moonlight-kvm

# On PC (if shutting down)
sudo systemctl stop sunshine-watchdog
sudo systemctl stop sunshine
```

### Monitoring

#### Check System Status

**PC:**

```bash
bash /usr/local/bin/check-status.sh
```

**Pi:**

```bash
bash /usr/local/bin/network-check.sh
systemctl status moonlight-kvm
```

#### View Logs

**PC:**

```bash
# Sunshine logs
journalctl -u sunshine -f

# Watchdog logs
journalctl -u sunshine-watchdog -f

# All logs
tail -f /var/log/sunshine-*.log
```

**Pi:**

```bash
# Moonlight logs
journalctl -u moonlight-kvm -f

# Connection logs
tail -f /var/log/moonlight-connection.log
```

#### Resource Monitoring

**PC:**

```bash
# CPU/Memory
htop

# Network usage
iftop

# GPU usage (NVIDIA)
nvidia-smi

# GPU usage (Intel)
intel_gpu_top
```

**Pi:**

```bash
# CPU/Memory
htop

# Temperature
vcgencmd measure_temp

# Network
iftop
```

---

## Troubleshooting

### Quick Fixes

#### Problem: Sunshine web UI not accessible / Connection refused

**Symptoms**: Can't access `https://192.168.0.56:47990`, browser shows "Unable to connect"

**Solution**:
```bash
# 1. Check if Sunshine is running
systemctl status sunshine

# 2. If stopped, check logs for errors
journalctl -u sunshine -n 50

# 3. Common issue on Ubuntu 24.04: Wrong DISPLAY variable
# Find your display number:
pgrep -u $USER gnome-shell | head -1 | xargs -I {} cat /proc/{}/environ | tr '\0' '\n' | grep DISPLAY

# 4. Update sunshine.service with correct DISPLAY
# Edit /etc/systemd/system/sunshine.service
# Change Environment=DISPLAY=:0 to the correct display (e.g., :1)

# 5. Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart sunshine
```

#### Problem: Pi can't connect to PC

```bash
# 1. Check network
bash /usr/local/bin/network-check.sh

# 2. Verify PC is reachable
ping 192.168.0.56

# 3. Check Sunshine is running (on PC)
systemctl status sunshine

# 4. Restart Moonlight
sudo systemctl restart moonlight-kvm
```

#### Problem: Connection drops frequently

```bash
# 1. Check WiFi signal (Pi)
iwconfig wlan0

# 2. Check latency
ping -c 100 192.168.0.56
# Should be < 20ms average, < 1% loss

# 3. Disable WiFi power management (Pi)
sudo iwconfig wlan0 power off

# 4. Check PC watchdog is running
systemctl status sunshine-watchdog
```

#### Problem: Video is stuttering/laggy

```bash
# 1. Lower resolution
# Edit /usr/local/bin/start-moonlight.sh
# Set VIDEO_WIDTH=1280, VIDEO_HEIGHT=720

# 2. Lower FPS
# Set VIDEO_FPS=30

# 3. Lower bitrate
# Set VIDEO_BITRATE=8000

# 4. Check Pi temperature
vcgencmd measure_temp
# Should be < 80°C

# 5. Check network latency
ping 192.168.0.56
```

#### Problem: No audio

```bash
# On PC - verify audio sink
pactl list short sinks

# On Pi - verify audio output
aplay -l

# In Moonlight config
# Ensure audio=true in start-moonlight.sh
```

### Complete Troubleshooting Guide

See `recovery/troubleshooting-card.md` for comprehensive troubleshooting steps.

**Print this card and keep near equipment!**

---

## Maintenance

### Daily Checks

- [ ] System is streaming correctly
- [ ] No error messages in logs
- [ ] Acceptable latency and video quality

### Weekly Maintenance

```bash
# PC
bash /usr/local/bin/check-status.sh
df -h  # Check disk space
journalctl --vacuum-time=7d  # Clean old logs

# Pi
bash /usr/local/bin/network-check.sh
df -h  # Check SD card space
vcgencmd measure_temp  # Check temperature
```

### Monthly Maintenance

1. **Review logs for patterns:**
   
   ```bash
   # PC
   journalctl -u sunshine --since "30 days ago" | grep ERROR

   # Pi
   journalctl -u moonlight-kvm --since "30 days ago" | grep ERROR
   ```

2. **Update system (during maintenance window):**
   
   ```bash
   # PC
   sudo apt update && sudo apt upgrade

   # Pi
   sudo apt update && sudo apt upgrade
   sudo rpi-update  # Firmware updates
   ```

3. **Verify backups:**
   
   ```bash
   ls -lh /var/backups/kvm-system/
   ```

4. **Test recovery procedures:**
   - Practice emergency restart
   - Verify troubleshooting card is accurate
   - Test with other lab users

### Quarterly Maintenance

- Replace SD card on Pi (they wear out)
- Review and update documentation
- Audit network configuration
- Check for security updates
- Review firewall rules

---

## Recovery Procedures

### Emergency Restart

**Sunshine (PC):**

```bash
sudo bash /usr/local/bin/emergency-restart-pc.sh
```

**Moonlight (Pi):**

```bash
sudo bash /usr/local/bin/emergency-restart-pi.sh
```

### Complete System Reset

If everything is broken:

1. **Reboot both systems:**
   
   ```bash
   # Pi
   sudo reboot

   # PC
   sudo reboot
   ```

2. **Wait for boot** (3 minutes for PC, 1 minute for Pi)

3. **Verify services:**
   
   ```bash
   # PC
   systemctl status sunshine sunshine-watchdog

   # Pi
   systemctl status moonlight-kvm
   ```

4. **Test connection:**
   - Desktop should appear on Pi monitor
   - If not, check logs and run diagnostics

### Restoring from Backup

If configuration is corrupted:

```bash
# PC
ls /var/backups/kvm-system/
# Choose most recent backup
cd /var/backups/kvm-system/YYYYMMDD_HHMMSS/

# Review files and selectively restore
# DON'T blindly restore everything!

# Example: Restore network config
sudo cp network/interfaces /etc/network/interfaces

# Restart affected services
sudo systemctl restart networking
```

### Re-pairing Moonlight

If pairing is lost:

```bash
# On Pi
moonlight pair 192.168.0.56

# Enter PIN in Sunshine web UI
# https://192.168.0.56:47990

# Verify
moonlight list 192.168.0.56
```

### Reinstalling from Scratch

If system is completely broken:

**PC:**

```bash
# From project root
cd wireless-kvm-lab/pc-side
sudo bash backup-config.sh  # Backup first!
sudo bash install-sunshine.sh
# Follow installation guide Phase 2
```

**Pi:**

```bash
# From Pi home directory
cd ~/wireless-kvm-lab/pi-side
# Or reflash SD card with fresh Pi OS and follow Phase 3
```

---

## Support & Documentation

### Project Structure

```text
wireless-kvm-lab/
├── README.md                    # This file
├── pc-side/                     # PC scripts and configs
│   ├── install-sunshine.sh
│   ├── sunshine.service
│   ├── sunshine-watchdog.sh
│   ├── sunshine-watchdog.service
│   ├── disable-power-management.sh
│   ├── check-status.sh
│   └── backup-config.sh
├── pi-side/                     # Pi 4 scripts and configs
│   ├── install-moonlight.sh
│   ├── moonlight-kvm.service
│   ├── start-moonlight.sh
│   └── network-check.sh
├── recovery/                    # Emergency procedures
│   ├── troubleshooting-card.md
│   ├── emergency-restart-pc.sh
│   └── emergency-restart-pi.sh
├── config/                      # Configuration templates
│   ├── sunshine-config.json
│   └── network-settings.md
└── logs/                        # Log storage (created at runtime)
```

### Key Log Locations

**PC:**

- `/var/log/sunshine-install.log` - Installation log
- `/var/log/kvm-power-management.log` - Power management changes
- `journalctl -u sunshine` - Sunshine service logs
- `journalctl -u sunshine-watchdog` - Watchdog logs
- `/var/log/emergency-restart.log` - Emergency restart actions

**Pi:**

- `/var/log/moonlight-install.log` - Installation log
- `/var/log/moonlight-connection.log` - Connection attempts/errors
- `journalctl -u moonlight-kvm` - Service logs
- `/var/log/emergency-restart.log` - Emergency restart actions

### External Resources

- **Sunshine Documentation:** <https://docs.lizardbyte.dev/projects/sunshine/>
- **Moonlight Documentation:** <https://moonlight-stream.org/>
- **Raspberry Pi Documentation:** <https://www.raspberrypi.org/documentation/>
- **Ubuntu Server Guide:** <https://ubuntu.com/server/docs>

---

## Security Considerations

### Network Security

1. **Firewall:** Sunshine ports restricted to local network only
2. **Encryption:** All streaming traffic is encrypted
3. **Authentication:** Strong password on Sunshine web UI
4. **Network isolation:** Consider separate VLAN for lab equipment

### System Security

1. **Updates:** Keep both systems updated (schedule during maintenance windows)
2. **SSH:** Use key-based authentication, disable password auth
3. **Sudo:** Limit sudo access to necessary users only
4. **Monitoring:** Review logs regularly for suspicious activity

### Physical Security

1. **Access control:** Lab room should be secured
2. **Power:** Use UPS to prevent data corruption
3. **Cooling:** Ensure adequate ventilation for 24/7 operation

---

## Performance Tuning

### Pi 4 Model B Capabilities

The Pi 4 Model B has excellent resources for streaming:

- **CPU:** Quad-core 1.5GHz ARM Cortex-A72
- **RAM:** 1GB to 8GB (depending on model)
- **GPU:** VideoCore VI (excellent H.264/H.265 decode)

**Recommended settings for best experience:**

- Resolution: 1920x1080 (Full HD) or 3840x2160 (4K)
- FPS: 60 for 1080p, 30 for 4K
- Bitrate: 20000 Kbps for 1080p60, 50000 Kbps for 4K30
- Codec: H.264 or H.265 (both hardware accelerated)

### PC Optimization

**For NVIDIA GPUs:**

```bash
# Ensure NVENC is being used
journalctl -u sunshine | grep -i encoder
```

**For Intel GPUs:**

```bash
# Ensure QSV is being used
journalctl -u sunshine | grep -i encoder
```

**CPU encoding (fallback):**

- Use "superfast" preset
- Enable "zerolatency" tune
- Limit to 30fps


---

## FAQ

**Q: Can I use this over the internet?**
A: Not recommended. This system is optimized for local network use. Internet streaming requires additional configuration and security considerations.

**Q: Can I use a Pi Zero 2W instead of Pi 4?**
A: Yes, but with reduced performance. Pi Zero 2W is more compact but limited to 720p30 or 1080p30. Pi 4 provides much better performance for smooth 1080p60 or 4K30 streaming.

**Q: Can multiple Pis connect to one PC?**
A: Yes, Sunshine supports multiple simultaneous connections. Each Pi needs to be paired separately.

**Q: What if my network uses different IP ranges?**
A: Update all IP addresses in scripts and config files as documented in "Changing IP Addresses" section.

**Q: How much bandwidth does this use?**
A: Approximately 10-20 Mbps for 1080p @ 30fps, depending on content and settings.

**Q: Can I add audio?**
A: Yes, audio is supported. Ensure PulseAudio/PipeWire is configured on PC and audio device is connected to Pi.

**Q: What about multiple monitors on PC?**
A: Sunshine can capture specific monitors. Configure in Sunshine web UI.

**Q: Is there input lag?**
A: Typically 30-60ms on local network, which is acceptable for most lab work. Gaming would require optimization.

---

## License & Attribution

This project uses:

- **Sunshine** by LizardByte (GPLv3)
- **Moonlight** by Moonlight Game Streaming Project (GPLv3)

All scripts in this project are provided as-is for lab use.

---

## Changelog

### Version 1.0 (2025-11-17)

**Initial production-ready release for SKIM Lab**

- Complete PC and Pi 4 setup scripts with auto-detection
- Systemd service files with watchdog monitoring
- Comprehensive monitoring and diagnostics tools
- Emergency recovery procedures
- Full documentation with troubleshooting guide
- Tested and verified working configuration

**Key learnings during development:**
- Moonlight-Qt requires `--resolution 1920x1080` flag (NOT `--1080`) for proper quality
- User-level Sunshine service works better than system-level for display access
- Pi 4 Model B handles 1080p60 @ 20Mbps with hardware decoding excellently
- H.264 codec provides better compatibility than HEVC for this setup

---

## Contributing

For improvements or bug fixes:

1. Test changes thoroughly in lab environment
2. Update documentation
3. Document any IP or system-specific changes
4. Test recovery procedures

---

## Contact

**Project maintained by:** Andrea (andrea96p@kaist.ac.kr)
**Lab:** SKIM Lab
**Institution:** KAIST
**GitHub:** https://github.com/andrea966p/RPi-Wireless-Streaming

For issues or questions, consult the troubleshooting guide first, then contact lab IT support.

---

**Last Updated:** 2025-11-17
**System Version:** 1.0
**Status:** Tested and Production-Ready
