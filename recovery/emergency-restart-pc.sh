#!/bin/bash
# Emergency Sunshine Restart Script
# Force restarts Sunshine service when it's unresponsive
# Can be run remotely via SSH

set -e

LOG_FILE="/var/log/emergency-restart.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

log "===== EMERGENCY SUNSHINE RESTART ====="
log "Triggered by: ${SUDO_USER:-root}"

# Stop Sunshine service
log "Stopping Sunshine service..."
systemctl stop sunshine || log "WARNING: Failed to stop service gracefully"

# Wait for service to stop
sleep 3

# Force kill any remaining Sunshine processes
log "Checking for remaining processes..."
if pgrep -x sunshine > /dev/null; then
    log "WARNING: Found remaining Sunshine processes"
    PIDS=$(pgrep -x sunshine | tr '\n' ' ')
    log "Killing PIDs: $PIDS"
    pkill -9 -x sunshine
    sleep 2
fi

# Clear any locks or temporary files
log "Clearing temporary files..."
rm -f /tmp/sunshine-*.lock 2>/dev/null || true
rm -f /run/sunshine-*.pid 2>/dev/null || true

# Start service
log "Starting Sunshine service..."
if systemctl start sunshine; then
    log "Sunshine service started successfully"

    # Wait for service to initialize
    sleep 5

    # Verify it's running
    if systemctl is-active --quiet sunshine; then
        log "✓ Sunshine is running"

        # Check if ports are listening
        if ss -tlnp | grep -q ":47990 \|:48010 "; then
            log "✓ Sunshine ports are listening"
            log "===== EMERGENCY RESTART SUCCESSFUL ====="
            echo ""
            echo "✓ Sunshine restarted successfully!"
            echo "  Check status: systemctl status sunshine"
            exit 0
        else
            log "WARNING: Ports not listening yet (may need more time)"
        fi
    else
        log "ERROR: Service not active after start"
    fi
else
    log "ERROR: Failed to start Sunshine service"
    log "===== EMERGENCY RESTART FAILED ====="
    echo ""
    echo "✗ Emergency restart failed!"
    echo "  Check logs: journalctl -u sunshine -n 50"
    echo "  Try manual intervention"
    exit 1
fi

log "Emergency restart completed with warnings"
echo ""
echo "⚠ Restart completed but with warnings"
echo "  Monitor status: watch systemctl status sunshine"
