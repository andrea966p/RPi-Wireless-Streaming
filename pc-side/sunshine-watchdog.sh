#!/bin/bash
# Sunshine Watchdog Script
# Monitors Sunshine service health and automatically restarts on failure
# Logs all actions for debugging and maintains system stability

set -e  # Exit on any error

# Configuration
LOG_FILE="/var/log/sunshine-watchdog.log"
CHECK_INTERVAL=30  # seconds between checks
MAX_RESTART_ATTEMPTS=5
RESTART_WINDOW=300  # 5 minutes - reset restart counter after this period
LAST_RESTART_FILE="/var/run/sunshine-watchdog-last-restart"
RESTART_COUNT_FILE="/var/run/sunshine-watchdog-restart-count"
ALERT_THRESHOLD=3  # Send alert after this many restarts

# Logging function with rotation
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"

    # Rotate log if it exceeds 10MB
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$log_size" -gt 10485760 ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log "Log rotated - previous log saved to ${LOG_FILE}.old"
        fi
    fi
}

# Initialize restart counter
get_restart_count() {
    if [ -f "$RESTART_COUNT_FILE" ]; then
        cat "$RESTART_COUNT_FILE"
    else
        echo 0
    fi
}

increment_restart_count() {
    local count=$(get_restart_count)
    echo $((count + 1)) > "$RESTART_COUNT_FILE"
}

reset_restart_count() {
    echo 0 > "$RESTART_COUNT_FILE"
    rm -f "$LAST_RESTART_FILE"
    log "Restart counter reset - system stable"
}

# Check if we're in the restart window
check_restart_window() {
    if [ ! -f "$LAST_RESTART_FILE" ]; then
        return 0
    fi

    local last_restart=$(cat "$LAST_RESTART_FILE")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_restart))

    if [ "$time_diff" -gt "$RESTART_WINDOW" ]; then
        # Outside window - reset counter
        reset_restart_count
        return 0
    fi

    return 1
}

# Check if Sunshine service is running
check_sunshine_service() {
    if systemctl is-active --quiet sunshine; then
        return 0
    else
        return 1
    fi
}

# Check if Sunshine is responding on its ports
check_sunshine_ports() {
    # Check if Sunshine is listening on primary HTTPS port (47990 or 48010)
    # Add small delay to allow service to start binding ports
    sleep 0.5
    if ss -tlnp 2>/dev/null | grep -qE ":(47990|48010)\s"; then
        return 0
    else
        return 1
    fi
}

# Check Sunshine process health
check_sunshine_process() {
    local sunshine_pid=$(systemctl show sunshine -p MainPID --value 2>/dev/null)

    if [ -z "$sunshine_pid" ] || [ "$sunshine_pid" = "0" ]; then
        return 1
    fi

    # Check if process exists
    if ! ps -p "$sunshine_pid" > /dev/null 2>&1; then
        return 1
    fi

    # Check if process is responsive (not in D state)
    local proc_state=$(ps -p "$sunshine_pid" -o state= 2>/dev/null | tr -d ' ')
    if [ "$proc_state" = "D" ]; then
        log "WARNING: Sunshine process in uninterruptible sleep (D state)"
        return 1
    fi

    return 0
}

# Restart Sunshine service
restart_sunshine() {
    log "Attempting to restart Sunshine service..."

    # Check restart limits
    check_restart_window
    local restart_count=$(get_restart_count)

    if [ "$restart_count" -ge "$MAX_RESTART_ATTEMPTS" ]; then
        log "CRITICAL: Maximum restart attempts ($MAX_RESTART_ATTEMPTS) reached in $RESTART_WINDOW seconds"
        log "CRITICAL: Manual intervention required - stopping watchdog"
        # Send notification (placeholder - implement based on your notification system)
        # notify_admin "Sunshine watchdog: Max restart attempts reached"
        exit 1
    fi

    # Stop service first
    log "Stopping Sunshine service..."
    systemctl stop sunshine || log "WARNING: Failed to stop Sunshine gracefully"

    # Wait for service to fully stop
    sleep 3

    # Kill any remaining processes
    local remaining_pids=$(pgrep -x sunshine || true)
    if [ -n "$remaining_pids" ]; then
        log "WARNING: Found remaining Sunshine processes: $remaining_pids"
        log "Killing remaining processes..."
        pkill -9 -x sunshine || true
        sleep 2
    fi

    # Start service
    log "Starting Sunshine service..."
    if systemctl start sunshine; then
        log "Sunshine service started successfully"

        # Update restart tracking
        date +%s > "$LAST_RESTART_FILE"
        increment_restart_count
        local new_count=$(get_restart_count)
        log "Restart count: $new_count / $MAX_RESTART_ATTEMPTS (window: $RESTART_WINDOW seconds)"

        # Send alert if threshold reached
        if [ "$new_count" -ge "$ALERT_THRESHOLD" ]; then
            log "WARNING: Restart threshold reached ($new_count restarts)"
            # notify_admin "Sunshine restarted $new_count times - investigate"
        fi

        # Wait for service to stabilize
        sleep 10

        # Verify service is running
        if check_sunshine_service && check_sunshine_ports; then
            log "Sunshine service verified healthy after restart"
            return 0
        else
            log "ERROR: Sunshine service failed health check after restart"
            return 1
        fi
    else
        log "ERROR: Failed to start Sunshine service"
        increment_restart_count
        return 1
    fi
}

# Main monitoring loop
main() {
    log "===== Sunshine Watchdog Started ====="
    log "Check interval: ${CHECK_INTERVAL}s"
    log "Max restart attempts: $MAX_RESTART_ATTEMPTS in ${RESTART_WINDOW}s"
    log "Alert threshold: $ALERT_THRESHOLD restarts"

    local consecutive_failures=0
    local last_ok_time=$(date +%s)

    while true; do
        # Perform health checks
        local service_ok=true

        # Check 1: Service status
        if ! check_sunshine_service; then
            log "Health check FAILED: Service not running"
            service_ok=false
        fi

        # Check 2: Process health
        if [ "$service_ok" = true ] && ! check_sunshine_process; then
            log "Health check FAILED: Process not healthy"
            service_ok=false
        fi

        # Check 3: Network ports
        if [ "$service_ok" = true ] && ! check_sunshine_ports; then
            log "Health check FAILED: Ports not listening"
            service_ok=false
        fi

        # Handle health check results
        if [ "$service_ok" = true ]; then
            # All checks passed
            if [ "$consecutive_failures" -gt 0 ]; then
                log "Health check OK - service recovered"
                consecutive_failures=0
            fi
            last_ok_time=$(date +%s)

            # Check if we should reset restart counter
            local time_since_last_ok=$(( $(date +%s) - last_ok_time ))
            if [ "$time_since_last_ok" -gt "$RESTART_WINDOW" ]; then
                local current_count=$(get_restart_count)
                if [ "$current_count" -gt 0 ]; then
                    reset_restart_count
                fi
            fi
        else
            # Health check failed
            consecutive_failures=$((consecutive_failures + 1))
            log "Health check FAILED (attempt $consecutive_failures/3)"

            # Wait for 3 consecutive failures before restarting
            if [ "$consecutive_failures" -ge 3 ]; then
                log "Multiple consecutive failures detected - initiating restart"

                if restart_sunshine; then
                    consecutive_failures=0
                    log "Service restart successful"
                else
                    log "ERROR: Service restart failed"
                    # Will retry on next check
                fi
            fi
        fi

        # Sleep until next check
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals for graceful shutdown
trap 'log "Watchdog received shutdown signal"; exit 0' SIGTERM SIGINT

# Run main loop
main
