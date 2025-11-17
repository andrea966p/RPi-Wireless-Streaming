#!/bin/bash
# Backup Current System Configuration
# Creates a timestamped backup of all critical system settings before making changes
# This allows for safe rollback if issues occur

set -e  # Exit on any error

# Configuration
BACKUP_ROOT="/var/backups/kvm-system"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error_exit "This script must be run as root (use sudo)"
fi

# Create backup root directory if it doesn't exist
mkdir -p "$BACKUP_ROOT" || {
    echo "ERROR: Failed to create backup root directory: $BACKUP_ROOT"
    exit 1
}

log "===== System Backup Started ====="
log "Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory"

# Backup system information
log "Backing up system information..."
{
    echo "=== System Information ==="
    uname -a
    echo ""
    echo "=== Date ==="
    date
    echo ""
    echo "=== Uptime ==="
    uptime
    echo ""
    echo "=== Disk Usage ==="
    df -h
    echo ""
    echo "=== Memory Usage ==="
    free -h
} > "${BACKUP_DIR}/system-info.txt"

# Backup network configuration
log "Backing up network configuration..."
mkdir -p "${BACKUP_DIR}/network"
cp -r /etc/netplan "${BACKUP_DIR}/network/" 2>/dev/null || log "WARNING: No netplan config found"
cp /etc/network/interfaces "${BACKUP_DIR}/network/" 2>/dev/null || log "WARNING: No interfaces file found"
ip addr > "${BACKUP_DIR}/network/ip-addr.txt"
ip route > "${BACKUP_DIR}/network/ip-route.txt"
cat /etc/hosts > "${BACKUP_DIR}/network/hosts"
cat /etc/hostname > "${BACKUP_DIR}/network/hostname"

# Backup systemd services
log "Backing up systemd services..."
mkdir -p "${BACKUP_DIR}/systemd"
systemctl list-unit-files > "${BACKUP_DIR}/systemd/unit-files.txt"
systemctl list-units --type=service > "${BACKUP_DIR}/systemd/services.txt"

# Backup existing Sunshine configuration if present
if [ -d "/home/$SUDO_USER/.config/sunshine" ]; then
    log "Backing up Sunshine configuration..."
    mkdir -p "${BACKUP_DIR}/sunshine"
    cp -r "/home/$SUDO_USER/.config/sunshine" "${BACKUP_DIR}/sunshine/" || log "WARNING: Failed to backup Sunshine config"
fi

# Backup power management settings
log "Backing up power management settings..."
mkdir -p "${BACKUP_DIR}/power"
systemctl status sleep.target > "${BACKUP_DIR}/power/sleep-status.txt" 2>&1 || true
systemctl status suspend.target > "${BACKUP_DIR}/power/suspend-status.txt" 2>&1 || true
systemctl status hibernate.target > "${BACKUP_DIR}/power/hibernate-status.txt" 2>&1 || true

# Backup firewall rules
log "Backing up firewall rules..."
mkdir -p "${BACKUP_DIR}/firewall"
if command -v ufw &> /dev/null; then
    ufw status verbose > "${BACKUP_DIR}/firewall/ufw-status.txt" 2>&1 || true
fi
iptables-save > "${BACKUP_DIR}/firewall/iptables-rules.txt" 2>&1 || true

# Backup cron jobs
log "Backing up cron jobs..."
mkdir -p "${BACKUP_DIR}/cron"
crontab -l > "${BACKUP_DIR}/cron/root-crontab.txt" 2>&1 || echo "No root crontab" > "${BACKUP_DIR}/cron/root-crontab.txt"
if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" crontab -l > "${BACKUP_DIR}/cron/user-crontab.txt" 2>&1 || echo "No user crontab" > "${BACKUP_DIR}/cron/user-crontab.txt"
fi

# Backup installed packages
log "Backing up package list..."
dpkg --get-selections > "${BACKUP_DIR}/dpkg-selections.txt"
apt list --installed > "${BACKUP_DIR}/apt-installed.txt" 2>/dev/null

# Create backup manifest
log "Creating backup manifest..."
cat > "${BACKUP_DIR}/MANIFEST.txt" <<EOF
Backup Created: $(date)
Hostname: $(hostname)
User: $SUDO_USER
Kernel: $(uname -r)
Ubuntu Version: $(lsb_release -d | cut -f2)

Backup Contents:
- System information and resource usage
- Network configuration (netplan, interfaces, IP settings)
- Systemd service configurations
- Sunshine configuration (if present)
- Power management settings
- Firewall rules (UFW and iptables)
- Cron jobs (root and user)
- Installed package list

To restore from this backup, refer to the individual files and apply
changes manually after verifying they are appropriate for the current system.

CRITICAL: Do not blindly restore all settings - review each file first!
EOF

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Backup size: $BACKUP_SIZE"

# Create a "latest" symlink for easy access
ln -sfn "$BACKUP_DIR" "${BACKUP_ROOT}/latest"
log "Latest backup symlink updated"

# Clean up old backups (keep last 10)
log "Cleaning up old backups..."
cd "$BACKUP_ROOT"
ls -t | grep -E '^[0-9]{8}_[0-9]{6}$' | tail -n +11 | xargs -r rm -rf
REMAINING_BACKUPS=$(ls -t | grep -E '^[0-9]{8}_[0-9]{6}$' | wc -l)
log "Remaining backups: $REMAINING_BACKUPS"

# Set proper permissions
chown -R root:root "$BACKUP_DIR"
chmod -R 600 "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

log "===== Backup Completed Successfully ====="
log "Backup location: $BACKUP_DIR"
log "Latest backup link: ${BACKUP_ROOT}/latest"

echo ""
echo "✓ System backup completed successfully!"
echo "✓ Backup location: $BACKUP_DIR"
echo "✓ Backup size: $BACKUP_SIZE"
echo ""
echo "You can now safely proceed with system modifications."
echo "To restore, review files in: $BACKUP_DIR"
