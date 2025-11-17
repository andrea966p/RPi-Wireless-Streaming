# Network Configuration Guide

## Overview

This document describes the network configuration required for the wireless KVM system.

---

## Network Architecture

```text
┌─────────────────────────────────────────────────────┐
│                  Lab WiFi Network                   │
│                  192.168.0.0/24                     │
│                                                     │
│  ┌──────────────────┐         ┌─────────────────┐   │
│  │   Ubuntu PC      │         │  Pi 4 B         │   │
│  │   (Sunshine)     │◄───────►│  (Moonlight)    │   │
│  │                  │         │                 │   │
│  │  192.168.0.56    │         │  192.168.0.47   │   │
│  │  andrea          │         │  (DHCP/Static)  │   │
│  └──────────────────┘         └─────────────────┘   │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │           WiFi Router/Access Point           │   │
│  │              192.168.0.1                     │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## Current Configuration (TEST SETUP)

### Ubuntu PC (Sunshine Server)

- **Hostname**: `andrea`
- **IP Address**: `192.168.0.56` (static recommended)
- **Subnet Mask**: `255.255.255.0`
- **Gateway**: `192.168.0.1` (your router)
- **DNS**: `192.168.0.1` or `8.8.8.8`

### Pi 4 B (Moonlight Client)

- **Hostname**: `pi4hdmi` (or custom)
- **IP Address**: static `192.168.0.47`
- **Subnet Mask**: `255.255.255.0`
- **Gateway**: `192.168.0.1`
- **DNS**: `192.168.0.1` or `8.8.8.8`

---

## Production Configuration (RECORDING ROOM)

### To Be Updated When Moving to Production Lab

```text
TODO: Update these values when setting up in recording room
```

#### Ubuntu PC

- **Hostname**: `andrea`
- **IP Address**: `TBD`
- **Subnet Mask**: `TBD`
- **Gateway**: `TBD`
- **DNS**: `TBD`

#### Pi Zero 2W

- **Hostname**: `lab-kvm-pi`
- **IP Address**: `TBD`
- **Subnet Mask**: `TBD`
- **Gateway**: `TBD`
- **DNS**: `TBD`

### Files to Update After IP Change

When moving to production, update IP addresses in:

1. `pc-side/check-status.sh` - PC_IP variable
1. `pi-side/install-moonlight.sh` - PC_IP variable
1. `pi-side/start-moonlight.sh` - PC_IP variable
1. `pi-side/network-check.sh` - PC_IP variable
1. `recovery/emergency-restart-pi.sh` - PC_IP variable
1. `recovery/troubleshooting-card.md` - Network Information section

---

## Network Requirements

### Bandwidth

- **Minimum**: 10 Mbps (720p @ 30fps)
- **Recommended**: 20+ Mbps (1080p @ 30fps)
- **Optimal**: 50+ Mbps (1080p @ 60fps)

### Latency

- **Good**: 5-20ms
- **Acceptable**: 20-50ms
- **Poor**: > 50ms (will experience noticeable lag)

### Packet Loss

- **Target**: 0%
- **Maximum acceptable**: < 1%

---

## Required Firewall Rules

### On Ubuntu PC (Sunshine)

#### UFW Configuration

```bash
# Allow Sunshine ports
sudo ufw allow 47984:47990/tcp comment "Sunshine TCP"
sudo ufw allow 47998:48000/udp comment "Sunshine UDP"
sudo ufw allow 48010/tcp comment "Sunshine HTTPS"

# Optional: Restrict to local network only
sudo ufw allow from 192.168.0.0/24 to any port 47984:47990 proto tcp
sudo ufw allow from 192.168.0.0/24 to any port 47998:48000 proto udp
sudo ufw allow from 192.168.0.0/24 to any port 48010 proto tcp
```

### Port Reference

 
| Port  | Protocol | Purpose                  |
|-------|----------|--------------------------|
| 47984 | TCP      | HTTPS Web UI             |
| 47989 | TCP      | Control port             |
| 47990 | TCP      | HTTP Web UI              |
| 47998 | UDP      | Video stream             |
| 47999 | UDP      | Audio stream             |
| 48010 | TCP      | Alternative HTTPS        |

---

## Static IP Configuration

### Ubuntu PC (Netplan)

1. Edit netplan configuration:

```bash
sudo nano /etc/netplan/01-network-manager-all.yaml
```

1. Add static configuration:

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:  # or your interface name
      dhcp4: no
      addresses:
  - 192.168.0.56/24
      gateway4: 192.168.0.1
      nameservers:
        addresses:
          - 192.168.0.1
          - 8.8.8.8
```

1. Apply configuration:

```bash
sudo netplan apply
```

### Pi Zero 2W (dhcpcd)

1. Edit dhcpcd configuration:

```bash
sudo nano /etc/dhcpcd.conf
```

1. Add static configuration:

```conf
interface wlan0
static ip_address=192.168.0.47/24
static routers=192.168.0.1
static domain_name_servers=192.168.0.1 8.8.8.8
```

1. Restart networking:

```bash
sudo systemctl restart dhcpcd
```

---

## WiFi Configuration (Pi 4 B)

### Using wpa_supplicant

1. Edit WiFi configuration:

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

1. Add network configuration:

```conf
country=US  # Your country code
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="Your_Lab_WiFi_SSID"
    psk="Your_WiFi_Password"
    key_mgmt=WPA-PSK
    priority=10
}

# Optional: Fallback network
network={
    ssid="Backup_WiFi_SSID"
    psk="Backup_Password"
    key_mgmt=WPA-PSK
    priority=5
}
```

1. Restart WiFi:

```bash
sudo systemctl restart wpa_supplicant
sudo systemctl restart dhcpcd
```

---

## Network Optimization

### On Ubuntu PC

1. **Disable power management on network interface**:

```bash
# Check current setting
ethtool eth0 | grep "Wake-on"

# Disable power management
sudo ethtool -s eth0 wol d

# Make permanent (add to /etc/rc.local or create systemd service)
```

1. **Increase network buffers** (already done in install-sunshine.sh):

```bash
sudo sysctl -w net.core.rmem_max=8388608
sudo sysctl -w net.core.wmem_max=8388608
```

### On Pi Zero 2W

Network optimizations are applied automatically by `install-moonlight.sh`.

To verify:

```bash
sysctl net.ipv4.tcp_low_latency
sysctl net.core.rmem_max
```

---

## Testing Network Performance

### Latency Test

```bash
# From Pi 4 to PC
ping -c 100 192.168.0.56
```

- Average < 10ms
- 0% packet loss
- Low stddev (jitter)

### Bandwidth Test

```bash
# Install iperf3 on both systems
sudo apt install -y iperf3

# On PC (server):
iperf3 -s

# On Pi (client):
iperf3 -c 192.168.0.56 -t 30
```

### Continuous Monitoring

```bash
# Monitor latency every 5 seconds
watch -n 5 'ping -c 4 192.168.0.56'

# Monitor WiFi quality (Pi 4)
watch -n 1 'iwconfig wlan0'
```

---

## Troubleshooting Network Issues

### Pi Cannot See PC

1. **Check basic connectivity**:

```bash
ip addr show  # Verify IP address
ip route      # Verify gateway
ping 192.168.0.1  # Test gateway
ping 192.168.0.56  # Test PC
```

1. **Check WiFi status**:

```bash
iwconfig wlan0
sudo wpa_cli status
```

1. **Restart networking**:

```bash
sudo systemctl restart dhcpcd
sudo systemctl restart wpa_supplicant
```

### High Latency

1. **Check WiFi signal strength**:

```bash
iwconfig wlan0 | grep "Signal level"
# Should be > -70 dBm for good performance
```

1. **Scan for interference**:

```bash
sudo iwlist wlan0 scan | grep -E "ESSID|Channel|Quality"
```

1. **Move Pi closer to router or use WiFi extender**

### Connection Drops

1. **Disable WiFi power management**:

```bash
sudo iwconfig wlan0 power off

# Make permanent (add to /etc/rc.local)
echo "iwconfig wlan0 power off" | sudo tee -a /etc/rc.local
```

1. **Check for network conflicts**:

```bash
# Verify no IP conflicts
sudo arping -I wlan0 192.168.0.56
```

---

## Security Considerations

1. **Use WPA2/WPA3** for WiFi
1. **Strong WiFi password** (minimum 20 characters)
1. **Disable WPS** on router
1. **MAC filtering** (optional, but adds layer of security)
1. **Separate VLAN** for lab equipment (advanced)
1. **Firewall rules** restrict to local network only

---

## Maintenance

### Weekly

- Check WiFi signal strength
- Verify latency is stable
- Review network logs for errors

### Monthly

- Update router firmware
- Review and optimize WiFi channels
- Test failover procedures

### After Any Change

- Run network-check.sh on Pi
- Run check-status.sh on PC
- Test actual streaming performance

---

## Additional Resources

- Ubuntu Networking: <https://netplan.io/>
- Raspberry Pi WiFi: <https://www.raspberrypi.org/documentation/configuration/wireless/>
- Sunshine Network Docs: <https://docs.lizardbyte.dev/projects/sunshine/>
- Moonlight Network Requirements: <https://github.com/moonlight-stream/moonlight-docs/wiki/Network-Setup>

---

**Last Updated**: [Date]
**Configuration Version**: 1.0 (Test Setup)
