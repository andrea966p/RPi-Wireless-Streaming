#!/bin/bash
# Emergency Moonlight Restart Script
# Force restarts Moonlight service when connection is broken
# Run this directly on Pi 4 or via SSH

set -e

LOG_FILE="/var/log/emergency-restart.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

log "===== EMERGENCY MOONLIGHT RESTART ====="
log "Triggered by: ${SUDO_USER:-root}"

# Stop Moonlight service
log "Stopping Moonlight service..."
systemctl stop moonlight-kvm || log "WARNING: Failed to stop service gracefully"

# Wait for service to stop
sleep 2

# Force kill any remaining Moonlight processes
log "Checking for remaining processes..."
if pgrep -x moonlight > /dev/null; then
    log "WARNING: Found remaining Moonlight processes"
    PIDS=$(pgrep -x moonlight | tr '\n' ' ')
    log "Killing PIDs: $PIDS"
    pkill -9 -x moonlight
    sleep 2
fi

# Clear any locks or temporary files
log "Clearing temporary files..."
rm -f /tmp/moonlight-*.lock 2>/dev/null || true
rm -f /run/moonlight-*.pid 2>/dev/null || true

# Quick network check
log "Checking network connectivity..."
PC_IP="192.168.0.56"
if ping -c 2 -W 3 "$PC_IP" > /dev/null 2>&1; then
    log "✓ PC is reachable"
else
    log "WARNING: Cannot reach PC at $PC_IP"
    echo ""
    echo "⚠ WARNING: Cannot reach PC!"
    echo "  Check network connection before starting Moonlight"
    echo "  PC IP: $PC_IP"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restart cancelled by user"
        exit 1
    fi
fi

# Start service
log "Starting Moonlight service..."
if systemctl start moonlight-kvm; then
    log "Moonlight service started successfully"

    # Wait for service to initialize
    sleep 5

    # Verify it's running
    if systemctl is-active --quiet moonlight-kvm; then
        log "✓ Moonlight service is active"

        # Check if Moonlight process is running
        if pgrep -x moonlight > /dev/null; then
            MOONLIGHT_PID=$(pgrep -x moonlight)
            log "✓ Moonlight process running (PID: $MOONLIGHT_PID)"
            log "===== EMERGENCY RESTART SUCCESSFUL ====="
            echo ""
            echo "✓ Moonlight restarted successfully!"
            echo "  Check status: systemctl status moonlight-kvm"
            echo "  View logs: journalctl -u moonlight-kvm -f"
            exit 0
        else
            log "WARNING: Service active but no Moonlight process found"
            log "This may be normal during connection retry"
        fi
    else
        log "ERROR: Service not active after start"
    fi
else
    log "ERROR: Failed to start Moonlight service"
    log "===== EMERGENCY RESTART FAILED ====="
    echo ""
    echo "✗ Emergency restart failed!"
    echo "  Check logs: journalctl -u moonlight-kvm -n 50"
    echo "  Verify pairing: moonlight list $PC_IP"
    exit 1
fi

log "Emergency restart completed with warnings"
echo ""
echo "⚠ Restart completed but with warnings"
echo "  Monitor status: watch systemctl status moonlight-kvm"
echo "  If issues persist, run: bash /usr/local/bin/network-check.sh"
