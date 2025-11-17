#!/bin/bash
# Sunshine Installation Script for Ubuntu PC
# This script downloads and installs the latest Sunshine streaming server
# with comprehensive error checking and logging

set -e  # Exit on any error

# Configuration
LOG_FILE="/var/log/sunshine-install.log"
BACKUP_DIR="/var/backups/sunshine-kvm"
SUNSHINE_VERSION="latest"  # Can be pinned to specific version for stability

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

log "===== Sunshine Installation Started ====="
log "System: $(uname -a)"
log "User: $SUDO_USER"

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
    libssl3 \
    libavcodec-dev \
    libavutil-dev \
    libswscale-dev \
    libdrm-dev \
    libevdev-dev \
    libpulse-dev \
    libopus-dev \
    libxtst-dev \
    libx11-dev \
    libxrandr-dev \
    libxfixes-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    libwayland-dev \
    libinput-dev \
    libudev-dev \
    libva-dev \
    libvdpau-dev \
    || error_exit "Failed to install dependencies"

log "Dependencies installed successfully"

# Detect architecture
ARCH=$(dpkg --print-architecture)
log "Detected architecture: $ARCH"

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
log "Detected Ubuntu version: $UBUNTU_VERSION"

# Determine which Sunshine package to download
if [ "${UBUNTU_VERSION%%.*}" -ge 24 ]; then
    SUNSHINE_UBUNTU_VERSION="24.04"
elif [ "${UBUNTU_VERSION%%.*}" -ge 22 ]; then
    SUNSHINE_UBUNTU_VERSION="22.04"
elif [ "${UBUNTU_VERSION%%.*}" -ge 20 ]; then
    SUNSHINE_UBUNTU_VERSION="20.04"
else
    error_exit "Unsupported Ubuntu version: $UBUNTU_VERSION. Sunshine requires Ubuntu 20.04 or newer."
fi

log "Will download Sunshine package for Ubuntu $SUNSHINE_UBUNTU_VERSION"

# Download Sunshine
log "Downloading Sunshine for Ubuntu ${SUNSHINE_UBUNTU_VERSION} (${ARCH})..."
DOWNLOAD_DIR="/tmp/sunshine-install-$$"
mkdir -p "$DOWNLOAD_DIR" || error_exit "Failed to create download directory"

cd "$DOWNLOAD_DIR"

# Get latest release URL from GitHub
SUNSHINE_DEB_URL="https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-ubuntu-${SUNSHINE_UBUNTU_VERSION}-${ARCH}.deb"

log "Downloading from: $SUNSHINE_DEB_URL"
wget -O sunshine.deb "$SUNSHINE_DEB_URL" || error_exit "Failed to download Sunshine"

# Verify download
if [ ! -f sunshine.deb ]; then
    error_exit "Downloaded file not found"
fi

FILE_SIZE=$(stat -f%z sunshine.deb 2>/dev/null || stat -c%s sunshine.deb)
log "Downloaded file size: $FILE_SIZE bytes"

if [ "$FILE_SIZE" -lt 1000000 ]; then
    error_exit "Downloaded file is too small, may be corrupted"
fi

# Install Sunshine
log "Installing Sunshine..."
apt-get install -y ./sunshine.deb || error_exit "Failed to install Sunshine package"

# Verify installation
if ! command -v sunshine &> /dev/null; then
    error_exit "Sunshine installation failed - command not found"
fi

SUNSHINE_PATH=$(which sunshine)
log "Sunshine installed at: $SUNSHINE_PATH"
log "Sunshine version: $(sunshine --version 2>&1 || echo 'Version check failed')"

# Create sunshine user if it doesn't exist (for running as dedicated user)
if ! id -u sunshine &> /dev/null; then
    log "Creating sunshine system user..."
    useradd -r -s /bin/false sunshine || log "WARNING: Failed to create sunshine user (may already exist)"
fi

# Set up configuration directory
SUNSHINE_CONFIG_DIR="/home/$SUDO_USER/.config/sunshine"
mkdir -p "$SUNSHINE_CONFIG_DIR" || error_exit "Failed to create config directory"
chown -R "$SUDO_USER:$SUDO_USER" "$SUNSHINE_CONFIG_DIR"
log "Configuration directory: $SUNSHINE_CONFIG_DIR"

# Enable required kernel modules for virtual input
log "Enabling kernel modules for virtual input..."
modprobe uinput || log "WARNING: Failed to load uinput module"
echo "uinput" > /etc/modules-load.d/sunshine.conf

# Set up udev rules for input access
log "Setting up udev rules..."
cat > /etc/udev/rules.d/85-sunshine-input.rules <<EOF
KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"
EOF

udevadm control --reload-rules
udevadm trigger
log "Udev rules configured"

# Configure firewall (if UFW is active)
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    log "Configuring UFW firewall..."
    ufw allow 47984:47990/tcp comment "Sunshine streaming" || log "WARNING: Failed to configure UFW"
    ufw allow 48010/tcp comment "Sunshine HTTPS" || log "WARNING: Failed to configure UFW"
    ufw allow 47998:48000/udp comment "Sunshine video/audio" || log "WARNING: Failed to configure UFW"
    log "Firewall rules added"
else
    log "UFW not active, skipping firewall configuration"
fi

# Clean up
log "Cleaning up temporary files..."
cd /
rm -rf "$DOWNLOAD_DIR"

# Create status check script
log "Creating status check script..."
cat > /usr/local/bin/sunshine-status <<'EOF'
#!/bin/bash
echo "=== Sunshine Status ==="
systemctl status sunshine 2>/dev/null || echo "Service not running"
echo ""
echo "=== Network Ports ==="
ss -tulpn | grep sunshine || echo "No ports open"
echo ""
echo "=== Recent Logs ==="
journalctl -u sunshine -n 20 --no-pager 2>/dev/null || echo "No logs available"
EOF
chmod +x /usr/local/bin/sunshine-status

log "===== Sunshine Installation Completed Successfully ====="
log "Next steps:"
log "1. Copy sunshine.service to /etc/systemd/system/"
log "2. Copy sunshine-watchdog files to appropriate locations"
log "3. Configure Sunshine using web interface at https://localhost:47990"
log "4. Run 'sudo systemctl enable --now sunshine' to start service"
log ""
log "Installation log saved to: $LOG_FILE"

echo ""
echo "✓ Sunshine installation completed successfully!"
echo "✓ Check $LOG_FILE for details"
echo ""
echo "Next: Configure the service files and start Sunshine"
