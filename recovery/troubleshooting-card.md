# Lab KVM Troubleshooting Quick Reference Card

**Print this card and keep it near the lab equipment**

---

## System Overview
- **PC**: Ubuntu running Sunshine streaming server (IP: 192.168.0.56, hostname: andrea)
- **Pi 4 Model B**: Running Moonlight client (IP: 192.168.0.47, hostname: pi4hdmi)
- **Purpose**: Wireless KVM for lab equipment control

---

## Quick Checks (Start Here!)

### 1. Is everything powered on?
- [ ] PC is on (lights/fans running)
- [ ] Pi 4 has power (LED on)
- [ ] Monitor/keyboard connected to Pi 4
- [ ] Both on same WiFi network

### 2. Can Pi reach PC?
On Pi 4, run:
ping 192.168.0.56
```
- If **success**: Network is OK, proceed to step 3
- If **fail**: Check network (see Network Issues below)
https://192.168.0.56:47990
```
- If **webpage loads**: Sunshine is running
- If **fail**: Sunshine needs restart (see below)

---

### Problem: "Cannot connect to PC"

**On Pi 4:**
```bash
# Check network
# Restart Moonlight
```

**On PC (via SSH or direct access):**
```bash
# Check Sunshine status
bash /usr/local/bin/check-status.sh

# Restart Sunshine
sudo systemctl restart sunshine
```

---

### Problem: "Black screen" or "Frozen image"

**On Pi 4:**
```bash
# Force restart Moonlight
sudo systemctl restart moonlight-kvm

# If that doesn't work, reboot Pi
sudo reboot
```
**On PC:**
```bash
# Restart Sunshine
sudo systemctl restart sunshine
```

---

### Problem: "Lag or stuttering"

**Check network quality on Pi 4:**
```bash
ping -c 10 192.168.0.56
```
- Latency should be < 10ms
- Packet loss should be 0%

**If latency is high:**
- Ensure no other devices streaming video
- Check for WiFi interference

---

### Problem: "PC won't respond"

ssh andrea@192.168.0.56
bash /usr/local/bin/recovery/emergency-restart-pc.sh
1. Go to PC physically
3. Login and run:
   ```bash
   sudo systemctl restart sunshine
   ```

---

### Problem: "PC freeze or GPU conflict"

**Symptoms:**
- System completely frozen, mouse/keyboard unresponsive
- Need to force restart (hard power button)
- Logs show NVENC or NvFBC errors
- Happens when running GPU-intensive applications alongside Sunshine

**Immediate Action:**
1. Force restart PC if completely frozen
2. After restart, check logs:
   ```bash
   sudo journalctl -u sunshine -n 100 | grep -i "error\|nvenc\|nvfbc"
   ```

**Prevention:**
- Avoid running these applications while Sunshine is active:
  - Electron-based apps (VSCode, Discord, Slack, Claude Desktop)
  - Video editing software (DaVinci Resolve, Blender)
  - Machine learning frameworks using GPU
  - Other game streaming software
  - Multiple Chrome/browser instances with hardware acceleration
- If you must run GPU apps, consider:
  - Temporarily stopping Sunshine: `sudo systemctl stop sunshine`
  - Using software rendering for other apps
  - Monitoring GPU usage: `nvidia-smi -l 1`

**Configuration Fix:**
- Sunshine config includes GPU conflict prevention settings
- See `/config/sunshine-config.json` for nvenc_realtime_hags and other options

---

## Emergency Procedures

### Complete System Restart

**Method 1: Soft restart (preferred)**
```bash
# On Pi 4:
sudo systemctl restart moonlight-kvm

# On PC (SSH or direct):
```

**Method 2: Full reboot**
```bash
# Reboot Pi 4:
sudo reboot

# Reboot PC:
sudo reboot
```
*Note: PC will take 2-3 minutes to boot. Pi takes ~30 seconds.*

---

### Reset to Working State

If everything is broken:

1. **Reboot both systems**
   ```bash
   # Pi 4:
   sudo reboot

   # PC:
   ```

2. **Wait 3 minutes** for both to boot

3. **Check PC status** (from another computer):
   ```bash
   ssh andrea@192.168.0.56
   sudo systemctl status sunshine
   ```

4. **Check Pi status** (on Pi terminal):
   ```bash
   sudo systemctl status moonlight-kvm
   ```

---

## Status Commands

### On PC:
```bash
# Full system status
bash /usr/local/bin/check-status.sh

# Sunshine service only
sudo systemctl status sunshine

sudo journalctl -u sunshine -n 50
```

### On Pi 4:
```bash
# Network check
bash /usr/local/bin/network-check.sh

# Moonlight service status
sudo systemctl status moonlight-kvm

# View recent errors
sudo journalctl -u moonlight-kvm -n 50
```

---

## Network Information

### Current Configuration (TEST SETUP):
- **PC IP**: 192.168.0.56
- **PC Hostname**: andrea
- **WiFi Network**: [Your Lab WiFi Name]

### Production Configuration (RECORDING ROOM):
- **PC IP**: TBD (will be updated)
- **PC Hostname**: andrea

---

## When to Call for Help
1. ❌ PC freezes repeatedly (possible GPU conflict - see above)
2. ❌ Sunshine web interface won't load after PC reboot
3. ❌ Multiple restarts don't fix the issue
4. ❌ GPU errors persist in logs after applying config fixes

---
## Preventive Maintenance

### Weekly:
- Check disk space on PC: `df -h`
- Check for system updates (schedule during downtime)

### Monthly:
- Review logs for recurring errors
- Test recovery procedures
- Verify backup of configuration files
---

## Important Files & Locations

- Logs: `/var/log/sunshine-*.log`
- Scripts: `/usr/local/bin/`
- Logs: `/var/log/moonlight-*.log`

---

## Support Resources
- Sunshine docs: https://docs.lizardbyte.dev/projects/sunshine/
- Moonlight docs: https://moonlight-stream.org/
**Last Updated**: [Date]
**Responsible**: [Your Name/Team]

---
┌─────────────────────────────────────────────────┐
├─────────────────────────────────────────────────┤
│ CHECK STATUS (PC):                              │
│   bash /usr/local/bin/check-status.sh          │
│                                                 │
│ CHECK STATUS (Pi):                              │
│                                                 │
│ RESTART SUNSHINE:                               │
│   sudo systemctl restart sunshine               │
│                                                 │
│ RESTART MOONLIGHT:                              │
│   sudo systemctl restart moonlight-kvm          │
│                                                 │
│ PING TEST:                                      │
│   ping 192.168.0.56                             │
│                                                 │
│ VIEW LOGS (PC):                                 │
│   sudo journalctl -u sunshine -n 50             │
│                                                 │
│ VIEW LOGS (Pi):                                 │
│   sudo journalctl -u moonlight-kvm -n 50        │
│                                                 │
│ REBOOT:                                         │
│   sudo reboot                                   │
└─────────────────────────────────────────────────┘
```
