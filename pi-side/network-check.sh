#!/bin/bash
# Network Connectivity Check for Pi 4
# Verifies network configuration and connectivity to PC
# Run this before starting Moonlight to diagnose issues

set -e

# Configuration
PC_IP="192.168.0.56"
PC_HOSTNAME="andrea"
SUNSHINE_PORTS="47984 47989 48010"

# Colors for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

OK="${GREEN}✓${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✗${NC}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Pi 4 Network Connectivity Check                 ║${NC}"
echo -e "${BLUE}║       $(date '+%Y-%m-%d %H:%M:%S')                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Information
echo -e "${BLUE}[System Information]${NC}"
echo "Hostname: $(hostname)"
echo "Pi Model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
echo "Kernel: $(uname -r)"
echo ""

# Network Interfaces
echo -e "${BLUE}[Network Interfaces]${NC}"
ip link show | grep -E "^[0-9]+:" | while read -r line; do
    iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
    state=$(echo "$line" | grep -oP '(?<=state )[A-Z]+' || echo "UNKNOWN")

    if [ "$state" = "UP" ]; then
        echo -e "$OK Interface $iface: $state"
    else
        echo -e "$WARN Interface $iface: $state"
    fi
done
echo ""

# IP Configuration
echo -e "${BLUE}[IP Configuration]${NC}"
local_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
if [ -n "$local_ip" ]; then
    echo -e "$OK Local IP: $local_ip"
else
    echo -e "$FAIL No IP address assigned"
fi

gateway=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$gateway" ]; then
    echo -e "$OK Gateway: $gateway"
else
    echo -e "$FAIL No default gateway"
fi

dns_servers=$(grep -E "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
if [ -n "$dns_servers" ]; then
    echo "DNS Servers: $dns_servers"
else
    echo -e "$WARN No DNS servers configured"
fi
echo ""

# Wireless Status (if using WiFi)
if [ -d /sys/class/net/wlan0 ]; then
    echo -e "${BLUE}[Wireless Status]${NC}"
    if command -v iwconfig &> /dev/null; then
        wifi_ssid=$(iwconfig wlan0 2>/dev/null | grep "ESSID" | cut -d'"' -f2)
        wifi_quality=$(iwconfig wlan0 2>/dev/null | grep "Link Quality" | awk '{print $2}' | cut -d'=' -f2)
        wifi_signal=$(iwconfig wlan0 2>/dev/null | grep "Signal level" | awk '{print $4}' | cut -d'=' -f2)

        if [ -n "$wifi_ssid" ]; then
            echo -e "$OK Connected to: $wifi_ssid"
            echo "   Quality: $wifi_quality"
            echo "   Signal: $wifi_signal"
        else
            echo -e "$WARN WiFi not connected"
        fi
    fi
    echo ""
fi

# Gateway Connectivity
echo -e "${BLUE}[Gateway Connectivity]${NC}"
if [ -n "$gateway" ]; then
    if ping -c 3 -W 3 "$gateway" > /dev/null 2>&1; then
        echo -e "$OK Gateway is reachable"
        avg_rtt=$(ping -c 3 -W 3 "$gateway" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
        echo "   Average RTT: ${avg_rtt}ms"
    else
        echo -e "$FAIL Cannot reach gateway"
    fi
else
    echo -e "$FAIL No gateway to test"
fi
echo ""

# Internet Connectivity
echo -e "${BLUE}[Internet Connectivity]${NC}"
if ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo -e "$OK Internet is reachable"
else
    echo -e "$WARN Cannot reach internet (not critical for LAN streaming)"
fi
echo ""

# PC Connectivity
echo -e "${BLUE}[PC Connectivity]${NC}"
echo "Target PC: $PC_IP ($PC_HOSTNAME)"

# DNS resolution
if host "$PC_HOSTNAME" > /dev/null 2>&1; then
    resolved_ip=$(host "$PC_HOSTNAME" | awk '/has address/ {print $4}' | head -1)
    echo -e "$OK DNS resolution: $PC_HOSTNAME -> $resolved_ip"
elif grep -q "$PC_HOSTNAME" /etc/hosts; then
    echo -e "$OK Hostname found in /etc/hosts"
else
    echo -e "$WARN Cannot resolve $PC_HOSTNAME (will use IP)"
fi

# Ping test
echo -n "Testing connectivity to PC... "
if ping -c 4 -W 3 "$PC_IP" > /dev/null 2>&1; then
    echo -e "$OK"
    avg_rtt=$(ping -c 10 -W 3 "$PC_IP" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
    packet_loss=$(ping -c 10 -W 3 "$PC_IP" 2>/dev/null | grep "packet loss" | awk '{print $6}')
    echo "   Average RTT: ${avg_rtt}ms"
    echo "   Packet loss: $packet_loss"

    # Assess latency quality
    latency_val=$(echo "$avg_rtt" | cut -d'.' -f1)
    if [ "$latency_val" -lt 5 ]; then
        echo -e "   ${GREEN}Excellent latency for streaming${NC}"
    elif [ "$latency_val" -lt 20 ]; then
        echo -e "   ${GREEN}Good latency for streaming${NC}"
    elif [ "$latency_val" -lt 50 ]; then
        echo -e "   ${YELLOW}Acceptable latency (may have minor lag)${NC}"
    else
        echo -e "   ${RED}High latency (streaming may be difficult)${NC}"
    fi
else
    echo -e "$FAIL"
    echo -e "   ${RED}Cannot reach PC - check if PC is powered on${NC}"
fi
echo ""

# Sunshine Port Check
echo -e "${BLUE}[Sunshine Service Check]${NC}"
for port in $SUNSHINE_PORTS; do
    echo -n "Port $port: "
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$PC_IP/$port" 2>/dev/null; then
        echo -e "$OK OPEN"
    else
        echo -e "$FAIL CLOSED or FILTERED"
    fi
done
echo ""

# Moonlight Status
echo -e "${BLUE}[Moonlight Status]${NC}"
if command -v moonlight &> /dev/null; then
    echo -e "$OK Moonlight is installed"
    moonlight_version=$(moonlight --version 2>&1 | head -1 || echo "Unknown")
    echo "   Version: $moonlight_version"

    # Check if already running
    if pgrep -x moonlight > /dev/null; then
        moonlight_pid=$(pgrep -x moonlight)
        echo -e "$WARN Moonlight is already running (PID: $moonlight_pid)"
    else
        echo "   Status: Not running"
    fi
else
    echo -e "$FAIL Moonlight is not installed"
fi
echo ""

# Pairing Status
echo -e "${BLUE}[Pairing Status]${NC}"
if command -v moonlight &> /dev/null; then
    echo "Checking if paired with $PC_IP..."
    if timeout 10 moonlight list "$PC_IP" > /dev/null 2>&1; then
        echo -e "$OK Paired with Sunshine server"
        echo "Available apps:"
        timeout 10 moonlight list "$PC_IP" 2>/dev/null | tail -n +2 | sed 's/^/   /'
    else
        echo -e "$WARN Not paired or cannot connect"
        echo "   Run: moonlight pair $PC_IP"
    fi
else
    echo -e "$FAIL Cannot check pairing - Moonlight not installed"
fi
echo ""

# System Resources
echo -e "${BLUE}[System Resources]${NC}"
cpu_temp=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 || echo "N/A")
echo "CPU Temperature: $cpu_temp"

mem_usage=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
echo "Memory Usage: $mem_usage"

gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | cut -d'=' -f2 || echo "N/A")
echo "GPU Memory: $gpu_mem"
echo ""

# Overall Assessment
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Overall Assessment                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

can_stream=true

if [ -z "$local_ip" ]; then
    echo -e "$FAIL No IP address - check network configuration"
    can_stream=false
fi

if ! ping -c 2 -W 3 "$PC_IP" > /dev/null 2>&1; then
    echo -e "$FAIL Cannot reach PC - ensure PC is powered on and connected"
    can_stream=false
fi

if ! timeout 3 bash -c "cat < /dev/null > /dev/tcp/$PC_IP/47984" 2>/dev/null; then
    echo -e "$FAIL Sunshine service not responding - start Sunshine on PC"
    can_stream=false
fi

if ! command -v moonlight &> /dev/null; then
    echo -e "$FAIL Moonlight not installed - run install-moonlight.sh"
    can_stream=false
fi

if [ "$can_stream" = true ]; then
    echo -e "${GREEN}✓ All checks passed - ready to stream!${NC}"
    echo ""
    echo "To start streaming:"
    echo "  moonlight stream $PC_IP"
    echo "Or enable auto-start service:"
    echo "  sudo systemctl enable --now moonlight-kvm"
else
    echo -e "${RED}✗ System not ready - fix issues above before streaming${NC}"
fi
echo ""
