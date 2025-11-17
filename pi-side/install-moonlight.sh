#!/bin/bash
# Moonlight Installation Script for Raspberry Pi 4 Model B
# Installs and configures Moonlight client for streaming from Sunshine server
# Optimized for Pi 4 Model B excellent performance

set -e  # Exit on any error

# Configuration
LOG_FILE="/var/log/moonlight-install.log"
BACKUP_DIR="/var/backups/moonlight-kvm"
PC_IP="192.168.0.56"
PC_HOSTNAME="andrea"

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

log "===== Moonlight Installation Started ====="
log "System: $(uname -a)"
log "Pi Model: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
log "Memory: $(free -h | awk '/^Mem:/ {print $2}')"

# Verify this is a Raspberry Pi
if [ ! -f /proc/device-tree/model ] || ! grep -qi "raspberry pi" /proc/device-tree/model; then
    log "WARNING: This doesn't appear to be a Raspberry Pi"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create backup directory
mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory"
log "Backup directory created: $BACKUP_DIR"

# Update package lists
log "Updating package lists..."
apt-get update || error_exit "Failed to update package lists"

# Install dependencies
log "Installing dependencies..."
apt-get install -y \
    wget \
    curl \
    libopus0 \
    libexpat1 \
    libavcodec-extra \
    libavutil59 \
    libssl3t64 \
    libasound2t64 \
    libpulse0 \
    libva2 \
    libva-drm2 \
    libvdpau1 \
    libdrm2 \
    libevdev2 \
    libudev1 \
    libsystemd0 \
    libdbus-1-3 \
    libgbm1 \
    libxkbcommon0 \
    || error_exit "Failed to install dependencies"

log "Dependencies installed successfully"

# Detect architecture
ARCH=$(dpkg --print-architecture)
log "Detected architecture: $ARCH"

if [ "$ARCH" != "armhf" ] && [ "$ARCH" != "arm64" ]; then
    error_exit "Unsupported architecture: $ARCH (expected armhf or arm64)"
fi

# Install Moonlight from official repository
log "Adding Moonlight Qt repository..."

# Detect the actual distribution (Raspberry Pi OS is based on Debian)
if [ -f /etc/rpi-issue ]; then
    DISTRO="raspbian"
else
    DISTRO="debian"
fi

CODENAME=$(lsb_release -cs)
log "Detected distribution: $DISTRO $CODENAME"

# Add Moonlight repository
log "Setting up Moonlight Qt repository..."
curl -1sLf 'https://dl.cloudsmith.io/public/moonlight-game-streaming/moonlight-qt/setup.deb.sh' | \
    distro=$DISTRO codename=$CODENAME bash || \
    error_exit "Failed to add Moonlight repository"

# Update package lists
log "Updating package lists after adding repository..."
apt-get update || error_exit "Failed to update package lists"

# Install Moonlight Qt
log "Installing Moonlight Qt from repository..."
apt-get install -y moonlight-qt || error_exit "Failed to install Moonlight Qt"

# Verify installation
if ! command -v moonlight-qt &> /dev/null; then
    error_exit "Moonlight installation failed - command not found"
fi

MOONLIGHT_PATH=$(which moonlight-qt)
log "Moonlight Qt installed at: $MOONLIGHT_PATH"

# Create symlink for convenience (optional)
if [ ! -f /usr/local/bin/moonlight ]; then
    ln -s /usr/bin/moonlight-qt /usr/local/bin/moonlight || log "WARNING: Could not create moonlight symlink"
fi

# Configure Moonlight
log "Configuring Moonlight..."
MOONLIGHT_CONFIG_DIR="/home/$SUDO_USER/.config/Moonlight Game Streaming Project"
mkdir -p "$MOONLIGHT_CONFIG_DIR" || error_exit "Failed to create config directory"

# Create initial configuration
cat > "$MOONLIGHT_CONFIG_DIR/Moonlight.conf" <<EOF
[General]
# Moonlight Configuration for Lab KVM
# Generated: $(date)

# Target PC
host=$PC_IP

# Video settings (optimized for Pi 4 Model B)
width=1920
height=1080
fps=60
bitrate=20000

# Audio
audio=true
audioBitrate=128

# Performance optimizations for Pi 4 Model B
framePacing=true
vsync=true
unsupportedHardware=false

# Input
absoluteMouseMode=true
gameOptimizations=false

# Logging
enableLogging=true
EOF

chown -R "$SUDO_USER:$SUDO_USER" "$MOONLIGHT_CONFIG_DIR"
log "Moonlight configuration created"

# Enable GPU memory for video decoding (optimized for Pi 4)
log "Configuring GPU memory allocation..."
if [ -f /boot/config.txt ]; then
    BOOT_CONFIG="/boot/config.txt"
elif [ -f /boot/firmware/config.txt ]; then
    BOOT_CONFIG="/boot/firmware/config.txt"
else
    log "WARNING: Could not find boot config.txt"
    BOOT_CONFIG=""
fi

if [ -n "$BOOT_CONFIG" ]; then
    # Backup original config
    cp "$BOOT_CONFIG" "${BOOT_CONFIG}.backup-$(date +%Y%m%d)"

    # Set GPU memory to 128MB (Pi 4 handles memory dynamically, doesn't need fixed allocation)
    # Pi 4 with 2GB+ RAM can use dynamic memory allocation
    if grep -q "^gpu_mem=" "$BOOT_CONFIG"; then
        sed -i 's/^gpu_mem=.*/gpu_mem=128/' "$BOOT_CONFIG"
        log "Updated existing gpu_mem setting to 128MB (Pi 4 uses dynamic allocation)"
    else
        echo "gpu_mem=128" >> "$BOOT_CONFIG"
        log "Added gpu_mem=128 to boot config (Pi 4 uses dynamic allocation)"
    fi

    # Enable hardware video decoding
    if ! grep -q "^dtoverlay=vc4-kms-v3d" "$BOOT_CONFIG"; then
        echo "dtoverlay=vc4-kms-v3d" >> "$BOOT_CONFIG"
        log "Enabled VC4 KMS video driver"
    fi

    log "GPU configuration updated (reboot required)"
fi

# Configure network settings for low latency
log "Optimizing network settings..."
cat > /etc/sysctl.d/90-moonlight-network.conf <<EOF
# Network optimizations for Moonlight streaming
# Increase network buffer sizes
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608

# Reduce network latency
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_timestamps = 0
EOF

sysctl -p /etc/sysctl.d/90-moonlight-network.conf || log "WARNING: Failed to apply network settings"

# Test connectivity to PC
log "Testing connectivity to Sunshine server..."
if ping -c 3 -W 5 "$PC_IP" > /dev/null 2>&1; then
    log "✓ Successfully pinged Sunshine server at $PC_IP"
else
    log "WARNING: Cannot reach Sunshine server at $PC_IP"
    log "         Verify network configuration and PC is powered on"
fi

# Add PC to known hosts
log "Adding PC to hosts file..."
if ! grep -q "$PC_HOSTNAME" /etc/hosts; then
    echo "$PC_IP    $PC_HOSTNAME" >> /etc/hosts
    log "Added $PC_HOSTNAME to /etc/hosts"
fi

# Configure auto-login (optional but recommended for kiosk mode)
log "Configuring auto-login..."
if [ -d /etc/systemd/system/getty@tty1.service.d ]; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SUDO_USER --noclear %I \$TERM
EOF
    systemctl daemon-reload
    log "Auto-login configured for $SUDO_USER"
fi

# Clean up
log "Cleaning up temporary files..."
apt-get autoremove -y || log "WARNING: apt autoremove failed"
apt-get clean || log "WARNING: apt clean failed"

log "===== Moonlight Installation Completed Successfully ====="
log "Next steps:"
log "1. Pair Moonlight with Sunshine server:"
log "   moonlight-qt pair $PC_IP"
log "2. Enter the PIN shown on the Sunshine web interface"
log "3. Test connection: moonlight-qt stream $PC_IP"
log "4. Copy systemd service files to auto-start on boot"
log "5. REBOOT to apply GPU memory changes"
log ""
log "Installation log saved to: $LOG_FILE"

echo ""
echo "✓ Moonlight Qt installation completed successfully!"
echo "✓ Check $LOG_FILE for details"
echo ""
echo "IMPORTANT: REBOOT required for GPU memory changes"
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. After reboot, pair with PC: moonlight-qt pair $PC_IP"
echo "   (Or use the symlink: moonlight pair $PC_IP)"
echo "3. Configure auto-start service"
