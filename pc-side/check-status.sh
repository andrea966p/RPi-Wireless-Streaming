#!/bin/bash
# System Status Monitoring Script
# Comprehensive health check for the KVM streaming system
# Use this to quickly diagnose issues and verify system health

set -e  # Exit on any error

# Configuration
PC_IP="192.168.0.56"
PC_HOSTNAME="andrea"
SUNSHINE_PORTS="47984 47989 48010"
SUNSHINE_UDP_PORTS="47998 47999 48000"

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Status indicators
OK="${GREEN}✓${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✗${NC}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       KVM Streaming System Status Check               ║${NC}"
echo -e "${BLUE}║       $(date '+%Y-%m-%d %H:%M:%S')                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Information
echo -e "${BLUE}[System Information]${NC}"
echo "Hostname: $(hostname)"
echo "IP Address: $(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)"
echo "Uptime: $(uptime -p)"
echo "Kernel: $(uname -r)"
echo ""

# CPU and Memory
echo -e "${BLUE}[Resource Usage]${NC}"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo "CPU Usage: ${CPU_USAGE}%"

MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
echo "Memory: ${MEM_USED} / ${MEM_TOTAL} (${MEM_PERCENT}%)"

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
echo "Disk Usage: ${DISK_USAGE}%"
echo ""

# Temperature (if sensors available)
if command -v sensors &> /dev/null; then
    echo -e "${BLUE}[Temperature]${NC}"
    sensors | grep -E "Core|temp" | head -5 || echo "Temperature sensors not available"
    echo ""
fi

# Network Status
echo -e "${BLUE}[Network Status]${NC}"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo -e "$OK Internet connectivity: OK"
else
    echo -e "$WARN Internet connectivity: DOWN"
fi

if ip addr show | grep -q "$PC_IP"; then
    echo -e "$OK Expected IP configured: $PC_IP"
else
    echo -e "$WARN Expected IP not found: $PC_IP"
fi

# Check default gateway
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$GATEWAY" ]; then
    if ping -c 1 -W 2 "$GATEWAY" &> /dev/null; then
        echo -e "$OK Gateway reachable: $GATEWAY"
    else
        echo -e "$FAIL Gateway unreachable: $GATEWAY"
    fi
else
    echo -e "$WARN No default gateway configured"
fi
echo ""

# Sunshine Service Status
echo -e "${BLUE}[Sunshine Service]${NC}"
if systemctl is-active --quiet sunshine 2>/dev/null; then
    echo -e "$OK Sunshine service: RUNNING"
    SUNSHINE_PID=$(systemctl show sunshine -p MainPID --value)
    echo "   PID: $SUNSHINE_PID"

    if [ -n "$SUNSHINE_PID" ] && [ "$SUNSHINE_PID" != "0" ]; then
        SUNSHINE_UPTIME=$(ps -p "$SUNSHINE_PID" -o etime= 2>/dev/null | xargs)
        echo "   Uptime: $SUNSHINE_UPTIME"

        SUNSHINE_MEM=$(ps -p "$SUNSHINE_PID" -o rss= 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        echo "   Memory: $SUNSHINE_MEM"
    fi
elif systemctl is-enabled --quiet sunshine 2>/dev/null; then
    echo -e "$WARN Sunshine service: STOPPED (but enabled)"
else
    echo -e "$FAIL Sunshine service: NOT INSTALLED or NOT ENABLED"
fi

# Check Sunshine ports
echo -e "${BLUE}[Sunshine Network Ports]${NC}"
for port in $SUNSHINE_PORTS; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "$OK TCP port $port: LISTENING"
    else
        echo -e "$WARN TCP port $port: NOT LISTENING"
    fi
done

for port in $SUNSHINE_UDP_PORTS; do
    if ss -ulnp 2>/dev/null | grep -q ":$port "; then
        echo -e "$OK UDP port $port: OPEN"
    else
        echo -e "$WARN UDP port $port: NOT OPEN"
    fi
done
echo ""

# Watchdog Service Status
echo -e "${BLUE}[Watchdog Service]${NC}"
if systemctl is-active --quiet sunshine-watchdog 2>/dev/null; then
    echo -e "$OK Watchdog service: RUNNING"
else
    echo -e "$WARN Watchdog service: NOT RUNNING"
fi
echo ""

# Power Management Status
echo -e "${BLUE}[Power Management]${NC}"
if systemctl is-enabled sleep.target 2>&1 | grep -q "masked"; then
    echo -e "$OK Sleep: DISABLED (masked)"
else
    echo -e "$WARN Sleep: ENABLED (should be masked for lab use)"
fi

if systemctl is-enabled suspend.target 2>&1 | grep -q "masked"; then
    echo -e "$OK Suspend: DISABLED (masked)"
else
    echo -e "$WARN Suspend: ENABLED (should be masked for lab use)"
fi

if systemctl is-enabled hibernate.target 2>&1 | grep -q "masked"; then
    echo -e "$OK Hibernate: DISABLED (masked)"
else
    echo -e "$WARN Hibernate: ENABLED (should be masked for lab use)"
fi
echo ""

# Firewall Status
echo -e "${BLUE}[Firewall]${NC}"
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "active"; then
        echo -e "$OK UFW: ACTIVE"
        echo "   Sunshine rules:"
        ufw status | grep -E "47984|47989|47998|48010" | sed 's/^/   /' || echo "   No Sunshine rules found"
    else
        echo -e "$WARN UFW: INACTIVE"
    fi
else
    echo -e "$WARN UFW: NOT INSTALLED"
fi
echo ""

# Recent Errors
echo -e "${BLUE}[Recent Sunshine Errors (last 10)]${NC}"
if systemctl is-active --quiet sunshine 2>/dev/null; then
    ERROR_COUNT=$(journalctl -u sunshine --since "1 hour ago" -p err --no-pager 2>/dev/null | grep -c "^-- " || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "$WARN Errors in last hour: $ERROR_COUNT"
        journalctl -u sunshine --since "1 hour ago" -p err --no-pager -n 10 2>/dev/null | sed 's/^/   /' || true
    else
        echo -e "$OK No errors in the last hour"
    fi
else
    echo "Sunshine not running - no logs available"
fi
echo ""

# Disk Health (SMART if available)
if command -v smartctl &> /dev/null; then
    echo -e "${BLUE}[Disk Health]${NC}"
    ROOT_DISK=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
    SMART_STATUS=$(sudo smartctl -H "$ROOT_DISK" 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}')
    if [ "$SMART_STATUS" = "PASSED" ]; then
        echo -e "$OK SMART status: PASSED"
    else
        echo -e "$WARN SMART status: $SMART_STATUS"
    fi
    echo ""
fi

# Connected Clients
echo -e "${BLUE}[Active Connections]${NC}"
SUNSHINE_CONNECTIONS=$(ss -tn 2>/dev/null | grep -E ":(47984|47989)" | wc -l)
if [ "$SUNSHINE_CONNECTIONS" -gt 0 ]; then
    echo -e "$OK Active connections: $SUNSHINE_CONNECTIONS"
    ss -tn 2>/dev/null | grep -E ":(47984|47989)" | awk '{print "   " $5}' | sed 's/:/ port /'
else
    echo "No active connections"
fi
echo ""

# Overall System Health
echo -e "${BLUE}[Overall Health Assessment]${NC}"
HEALTH_SCORE=100

# Deduct points for issues
systemctl is-active --quiet sunshine 2>/dev/null || ((HEALTH_SCORE-=30))
systemctl is-active --quiet sunshine-watchdog 2>/dev/null || ((HEALTH_SCORE-=10))
[ "${CPU_USAGE%.*}" -lt 90 ] 2>/dev/null || ((HEALTH_SCORE-=15))
[ "${MEM_PERCENT%.*}" -lt 90 ] 2>/dev/null || ((HEALTH_SCORE-=15))
[ "${DISK_USAGE%.*}" -lt 90 ] 2>/dev/null || ((HEALTH_SCORE-=10))
systemctl is-enabled sleep.target 2>&1 | grep -q "masked" || ((HEALTH_SCORE-=10))
ping -c 1 -W 2 8.8.8.8 &> /dev/null || ((HEALTH_SCORE-=10))

if [ "$HEALTH_SCORE" -ge 90 ]; then
    echo -e "${GREEN}System Health: EXCELLENT (${HEALTH_SCORE}/100)${NC}"
elif [ "$HEALTH_SCORE" -ge 70 ]; then
    echo -e "${GREEN}System Health: GOOD (${HEALTH_SCORE}/100)${NC}"
elif [ "$HEALTH_SCORE" -ge 50 ]; then
    echo -e "${YELLOW}System Health: FAIR (${HEALTH_SCORE}/100)${NC}"
else
    echo -e "${RED}System Health: POOR (${HEALTH_SCORE}/100) - ATTENTION REQUIRED${NC}"
fi

echo ""
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo "For detailed logs: journalctl -u sunshine -n 50"
echo "For live monitoring: watch -n 5 $(readlink -f $0)"
