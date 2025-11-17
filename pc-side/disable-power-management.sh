#!/bin/bash
# Disable Power Management for Lab KVM System
# Prevents sleep, suspend, and hibernation to ensure 24/7 availability
# Critical for scientific lab equipment that must remain accessible

set -e  # Exit on any error

# Configuration
LOG_FILE="/var/log/kvm-power-management.log"

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

log "===== Disabling Power Management ====="
log "WARNING: This will disable sleep, suspend, and hibernation"
log "System will remain powered on 24/7"

# Disable systemd sleep targets
log "Masking systemd sleep targets..."
systemctl mask sleep.target || error_exit "Failed to mask sleep.target"
systemctl mask suspend.target || error_exit "Failed to mask suspend.target"
systemctl mask hibernate.target || error_exit "Failed to mask hibernate.target"
systemctl mask hybrid-sleep.target || error_exit "Failed to mask hybrid-sleep.target"

# Verify masking
log "Verifying sleep targets are masked..."
for target in sleep suspend hibernate hybrid-sleep; do
    if systemctl is-enabled ${target}.target 2>&1 | grep -q "masked"; then
        log "✓ ${target}.target is masked"
    else
        log "WARNING: ${target}.target may not be properly masked"
    fi
done

# Configure logind to ignore lid close and power button
log "Configuring systemd-logind..."
LOGIND_CONF="/etc/systemd/logind.conf"
LOGIND_BACKUP="${LOGIND_CONF}.backup-$(date +%Y%m%d)"

# Backup original config
if [ ! -f "$LOGIND_BACKUP" ]; then
    cp "$LOGIND_CONF" "$LOGIND_BACKUP"
    log "Original logind.conf backed up to: $LOGIND_BACKUP"
fi

# Modify logind configuration
cat > "$LOGIND_CONF" <<EOF
# Logind Configuration - Modified for Lab KVM System
# Original backed up to: $LOGIND_BACKUP
# Modified: $(date)

[Login]
# Ignore lid close (for laptops)
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore

# Ignore power button (prevent accidental shutdown)
HandlePowerKey=ignore

# Ignore suspend key
HandleSuspendKey=ignore

# Ignore hibernate key
HandleHibernateKey=ignore

# Disable idle action
IdleAction=ignore
IdleActionSec=0

# Keep sessions alive
KillUserProcesses=no
EOF

log "logind.conf updated"

# Restart logind to apply changes
log "Restarting systemd-logind..."
systemctl restart systemd-logind || log "WARNING: Failed to restart logind (changes will apply on next boot)"

# Disable screen blanking and DPMS (for X11)
log "Disabling screen blanking..."
if [ -n "$SUDO_USER" ]; then
    XORG_CONF_DIR="/etc/X11/xorg.conf.d"
    mkdir -p "$XORG_CONF_DIR"

    cat > "${XORG_CONF_DIR}/10-monitor.conf" <<EOF
# Disable DPMS and screen blanking for lab KVM system
Section "ServerLayout"
    Identifier "ServerLayout0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
    Option "BlankTime" "0"
EndSection

Section "Monitor"
    Identifier "Monitor0"
    Option "DPMS" "false"
EndSection
EOF
    log "X11 monitor configuration created"
fi

# Disable GNOME power saving (if GNOME is installed)
if command -v gsettings &> /dev/null && [ -n "$SUDO_USER" ]; then
    log "Configuring GNOME power settings..."
    sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $SUDO_USER)/bus" gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || log "WARNING: Failed to set GNOME idle delay"
    sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $SUDO_USER)/bus" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || log "WARNING: Failed to set GNOME AC sleep"
    sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $SUDO_USER)/bus" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || log "WARNING: Failed to set GNOME battery sleep"
    log "GNOME power settings configured"
fi

# Disable automatic updates during working hours (optional but recommended for stability)
log "Configuring automatic updates..."
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
# Automatic update configuration for lab system
# Updates are disabled during installation to prevent unexpected reboots
# Re-enable and schedule updates manually during maintenance windows
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
EOF
log "Automatic updates configured (disabled)"

# Create a startup script to ensure settings persist
log "Creating startup enforcement script..."
cat > /usr/local/bin/enforce-kvm-power-settings <<'EOF'
#!/bin/bash
# Enforce power management settings on every boot
# This ensures settings persist even if something tries to change them

# Re-disable screen blanking
if [ -n "$DISPLAY" ]; then
    xset s off 2>/dev/null || true
    xset -dpms 2>/dev/null || true
    xset s noblank 2>/dev/null || true
fi

# Verify sleep targets are still masked
for target in sleep suspend hibernate hybrid-sleep; do
    systemctl is-enabled ${target}.target 2>&1 | grep -q "masked" || systemctl mask ${target}.target
done
EOF
chmod +x /usr/local/bin/enforce-kvm-power-settings

# Create systemd service for startup enforcement
cat > /etc/systemd/system/enforce-kvm-power.service <<EOF
[Unit]
Description=Enforce KVM Power Management Settings
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/enforce-kvm-power-settings
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable enforce-kvm-power.service
log "Startup enforcement service created and enabled"

# Verify current power settings
log "Verifying power management status..."
log "Sleep target status: $(systemctl is-enabled sleep.target 2>&1)"
log "Suspend target status: $(systemctl is-enabled suspend.target 2>&1)"
log "Hibernate target status: $(systemctl is-enabled hibernate.target 2>&1)"

log "===== Power Management Configuration Complete ====="
log "Summary of changes:"
log "  - Sleep, suspend, and hibernation disabled"
log "  - Lid close and power button ignored"
log "  - Screen blanking and DPMS disabled"
log "  - Automatic updates disabled (configure manually)"
log "  - Enforcement service enabled for boot"
log ""
log "System will remain powered on 24/7"
log "IMPORTANT: Configure physical security and UPS for lab equipment"

echo ""
echo "✓ Power management disabled successfully!"
echo "✓ System will remain accessible 24/7"
echo ""
echo "IMPORTANT NOTES:"
echo "  - Configure a UPS for power protection"
echo "  - Ensure adequate cooling for 24/7 operation"
echo "  - Plan maintenance windows for updates"
echo "  - Monitor system temperature and disk health"
echo ""
echo "Log file: $LOG_FILE"
