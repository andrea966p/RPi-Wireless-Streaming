#!/bin/bash
# Moonlight Connection Script with Auto-Retry
# Connects to Sunshine server with automatic retry on failure
# Designed for maximum reliability in lab environment

set -e  # Exit on any error for critical operations

# Configuration
PC_IP="192.168.0.56"
PC_HOSTNAME="andrea"
LOG_FILE="/var/log/moonlight-connection.log"
MAX_RETRIES=10
RETRY_DELAY=10  # seconds between retries
CONNECTION_TIMEOUT=15  # seconds to wait for connection

# Video settings optimized for Pi 4 Model B
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080
VIDEO_FPS=60
VIDEO_BITRATE=20000  # Kbps

# Logging function with rotation
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"

    # Rotate log if it exceeds 5MB
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$log_size" -gt 5242880 ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log "Log rotated - previous log saved to ${LOG_FILE}.old"
        fi
    fi
}

# Error handler that doesn't exit (for retry logic)
log_error() {
    log "ERROR: $1"
}

# Check network connectivity
check_network() {
    log "Checking network connectivity..."

    # Check if network interface is up
    if ! ip link show | grep -q "state UP"; then
        log_error "No network interface is up"
        return 1
    fi

    # Check if we have an IP address
    local ip_addr=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    if [ -z "$ip_addr" ]; then
        log_error "No IP address assigned"
        return 1
    fi
    log "Local IP: $ip_addr"

    # Check if we can reach the gateway
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        if ping -c 1 -W 3 "$gateway" > /dev/null 2>&1; then
            log "✓ Gateway reachable: $gateway"
        else
            log_error "Cannot reach gateway: $gateway"
            return 1
        fi
    else
        log_error "No default gateway configured"
        return 1
    fi

    # Check if we can reach the PC
    if ping -c 2 -W 3 "$PC_IP" > /dev/null 2>&1; then
        log "✓ PC reachable: $PC_IP"
    else
        log_error "Cannot reach PC: $PC_IP"
        return 1
    fi

    # Check if Sunshine ports are open
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$PC_IP/47984" 2>/dev/null; then
        log "✓ Sunshine port 47984 is open"
    else
        log_error "Sunshine port 47984 not responding"
        return 1
    fi

    return 0
}

# Check if Moonlight is already running
check_existing_instance() {
    if pgrep -x moonlight-qt > /dev/null; then
        log "WARNING: Moonlight-Qt is already running"
        log "Killing existing instance..."
        pkill -9 -x moonlight-qt
        sleep 2
    fi
}

# Start Moonlight streaming session
start_moonlight() {
    local attempt=$1

    log "===== Connection Attempt $attempt/$MAX_RETRIES ====="

    # Pre-flight checks
    check_existing_instance

    if ! check_network; then
        log_error "Network checks failed"
        return 1
    fi

    # Verify Moonlight-Qt is installed
    if ! command -v moonlight-qt &> /dev/null; then
        log_error "Moonlight-Qt not found - installation required"
        return 1
    fi

    # Start Moonlight in streaming mode
    log "Starting Moonlight connection to $PC_IP..."
    log "Video settings: ${VIDEO_WIDTH}x${VIDEO_HEIGHT} @ ${VIDEO_FPS}fps, ${VIDEO_BITRATE}kbps"

    # Run Moonlight-Qt with explicit 1080p60 settings
    # Must use --resolution flag (not --1080) for proper quality
    moonlight-qt stream \
        "$PC_IP" \
        "Desktop" \
        --resolution 1920x1080 \
        --fps 60 \
        --bitrate 20000 \
        --video-codec auto \
        --video-decoder auto \
        >> "$LOG_FILE" 2>&1 &

    local moonlight_pid=$!
    log "Moonlight started with PID: $moonlight_pid"

    # Wait and verify the connection
    sleep 5

    if ps -p $moonlight_pid > /dev/null 2>&1; then
        log "✓ Moonlight process is running"
        log "===== Connection Established Successfully ====="

        # Monitor the connection
        wait $moonlight_pid
        local exit_code=$?

        log "Moonlight exited with code: $exit_code"
        return $exit_code
    else
        log_error "Moonlight process died immediately after start"
        return 1
    fi
}

# Main retry loop
main() {
    log "========================================="
    log "Moonlight Auto-Connect Starting"
    log "Target: $PC_IP ($PC_HOSTNAME)"
    log "Max retries: $MAX_RETRIES"
    log "Retry delay: ${RETRY_DELAY}s"
    log "========================================="

    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        if start_moonlight $attempt; then
            log "Connection completed successfully"

            # If we get here, connection was active but has ended
            # This could be intentional or due to an error
            log "Checking if we should reconnect..."

            # Short delay before retry
            sleep 5

            # Reset attempt counter if we had a successful connection
            attempt=1
            log "Attempting to reconnect..."
        else
            log "Connection attempt $attempt failed"

            if [ $attempt -lt $MAX_RETRIES ]; then
                log "Waiting ${RETRY_DELAY} seconds before retry..."
                sleep $RETRY_DELAY

                # Increase delay exponentially for subsequent failures
                RETRY_DELAY=$((RETRY_DELAY * 2))
                if [ $RETRY_DELAY -gt 300 ]; then
                    RETRY_DELAY=300  # Cap at 5 minutes
                fi
            else
                log "===== Maximum retry attempts reached ====="
                log "Manual intervention required"
                log "Troubleshooting steps:"
                log "1. Verify PC is powered on"
                log "2. Check network connectivity: ping $PC_IP"
                log "3. Verify Sunshine is running on PC"
                log "4. Check pairing status: moonlight list $PC_IP"
                log "5. Review logs: journalctl -u moonlight-kvm"
                exit 1
            fi
        fi

        attempt=$((attempt + 1))
    done
}

# Handle signals for graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."
    pkill -TERM -x moonlight-qt || true
    sleep 2
    pkill -KILL -x moonlight-qt || true
    log "Cleanup complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Run main loop
main
