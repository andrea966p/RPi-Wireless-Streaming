# GPU Conflict Applications - Avoid Running with Sunshine

This document lists applications known to conflict with Sunshine's NVENC encoder and cause system instability, including potential PC freezes requiring hard restart.

## Critical Context

On **November 14, 2025**, the lab PC experienced a complete system freeze that required a forced restart. Log analysis revealed:

- **Claude Desktop** GPU process crashed with `SharedContextState context lost` error
- **Sunshine** simultaneously experienced NVENC and NvFBC failures
- Both applications were competing for the same NVIDIA GPU resources (video encoder)

This incident demonstrates that running GPU-intensive applications alongside Sunshine can cause driver crashes and system-wide instability.

---

## High-Risk Applications (Confirmed Conflicts)

### Electron-Based Applications

These apps use Chromium under the hood, which by default enables GPU hardware acceleration:

- **Claude Desktop** ⚠️ CONFIRMED CONFLICT - caused PC freeze on 2025-11-14
- **Visual Studio Code** - Uses GPU for rendering
- **Discord** - Hardware video encoding/decoding
- **Slack** - GPU-accelerated UI
- **Microsoft Teams** - Video processing
- **Spotify** (desktop app) - Hardware-accelerated UI
- **Notion** - GPU rendering
- **Obsidian** - GPU acceleration for canvas/graphs

**Why they conflict:** Electron apps request GPU resources for rendering, which can compete with Sunshine's exclusive access to NVENC and frame buffer capture (NvFBC).

**Mitigation (if you must run them):**
```bash
# Launch with software rendering (disables GPU)
code --disable-gpu
discord --disable-gpu --disable-hardware-acceleration
```

---

## Medium-Risk Applications

### Video/Graphics Processing

- **DaVinci Resolve** - Professional video editor (heavy NVENC/CUDA usage)
- **Blender** - 3D rendering (CUDA/OptiX)
- **OBS Studio** - Streaming software (competes for NVENC)
- **HandBrake** - Video transcoding (NVENC encoding)
- **FFmpeg** with hardware encoding - Direct NVENC access
- **Adobe Premiere Pro** / **After Effects** - GPU encoding/effects

**Why they conflict:** These tools directly use NVENC for video encoding, the same hardware component Sunshine requires.

### Web Browsers (Multiple Instances)

- **Google Chrome** (multiple windows/tabs)
- **Microsoft Edge** (Chromium-based)
- **Brave** / **Vivaldi** / Other Chromium browsers

**Why they conflict:** Modern browsers use GPU for video decode/encode (WebRTC, video playback), canvas rendering, and compositing. Multiple instances can saturate GPU resources.

**Mitigation:**
```bash
# Launch with software rendering
google-chrome --disable-gpu --disable-software-rasterizer
```

Or in browser settings: `chrome://flags` → Disable "Hardware acceleration"

### Machine Learning / AI Frameworks

- **PyTorch** with CUDA
- **TensorFlow** with GPU
- **Stable Diffusion** / **ComfyUI**
- **LLaMA.cpp** with CUDA
- **Ollama** with GPU acceleration

**Why they conflict:** These frameworks consume large amounts of VRAM and GPU compute, leaving insufficient resources for Sunshine's encoder.

### Game Streaming / Recording Software

- **GeForce Experience** / **ShadowPlay**
- **AMD ReLive**
- **XSplit**
- **Streamlabs**

**Why they conflict:** Direct competition for the same NVENC hardware encoder.

---

## Lower-Risk Applications (Use with Caution)

### Development Tools

- **Docker** containers with GPU passthrough (`--gpus all`)
- **WSL2** with GPU compute
- **Android Studio** emulator with GPU acceleration

### Communication Tools with Video

- **Zoom** - Hardware video encoding
- **Google Meet** - GPU-accelerated video
- **Skype** - Hardware acceleration

**Risk:** Only problematic during active video calls with screen sharing or multiple participants.

---

## Safe to Run Alongside Sunshine

These applications typically don't compete for GPU resources:

- **Terminal emulators** (GNOME Terminal, Alacritty, etc.)
- **Text editors** without GPU features (Vim, Nano, Gedit)
- **Web browsers** (single tab, no video) with HW acceleration disabled
- **File managers** (Nautilus, Dolphin)
- **PDF readers** (Evince, Okular)
- **Office suites** (LibreOffice, OnlyOffice)
- **Audio players/editors** (Audacity, VLC in audio mode)
- **Most CLI tools** and scripts

---

## Monitoring GPU Usage

Before starting Sunshine for critical lab work, check GPU usage:

```bash
# Real-time GPU monitoring
nvidia-smi -l 1

# Check for processes using GPU
nvidia-smi pmon -c 1

# Watch for NVENC usage specifically
nvidia-smi dmon -s u -c 1
```

**Red flags:**
- Multiple processes showing GPU usage
- VRAM usage > 80%
- Encoder utilization > 0% (when Sunshine isn't running)

---

## Recommended Workflow for Lab Use

### Before Starting Sunshine

1. Close all Electron apps (especially VSCode, Discord, Claude Desktop)
2. Stop any video processing or ML workloads
3. Check GPU is idle: `nvidia-smi`
4. Start Sunshine: `sudo systemctl start sunshine`

### During Lab Sessions

- **DO NOT** open heavy GPU applications
- **AVOID** browser-based video conferencing
- **LIMIT** browser tabs (< 10 tabs recommended)
- **MONITOR** for stuttering/lag (early warning of GPU contention)

### After Lab Sessions

1. Stop streaming on Pi
2. Check Sunshine logs for errors: `journalctl -u sunshine -n 100`
3. If you need GPU apps, optionally stop Sunshine: `sudo systemctl stop sunshine`

---

## Emergency Procedures for GPU Conflicts

### If PC Becomes Unresponsive

1. **Hard reset** (hold power button 5+ seconds)
2. **After reboot**, check logs:
   ```bash
   sudo journalctl -b -1 -n 200 | grep -i "gpu\|nvenc\|nvfbc\|error"
   ```
3. **Identify culprit** - look for application errors concurrent with Sunshine errors
4. **Prevent recurrence** - add offending app to your personal avoid list

### If You Must Run Conflicting Apps

**Option 1: Stop Sunshine temporarily**
```bash
sudo systemctl stop sunshine
# ... run your GPU-intensive work ...
sudo systemctl start sunshine
```

**Option 2: Use software rendering**
```bash
# Set environment variable for application
LIBGL_ALWAYS_SOFTWARE=1 your-app

# Or for Electron apps:
your-app --disable-gpu --disable-hardware-acceleration
```

**Option 3: Limit Sunshine GPU usage** (not recommended for lab use)
- Edit `~/.config/sunshine/sunshine.conf`
- Set `nvenc_preset=7` (slower encoding, less GPU stress)
- Reduce resolution/framerate
- See `config/sunshine-config.json` for details

---

## Configuration Applied

The Sunshine configuration in this repository includes GPU conflict prevention:

```json
"nvenc_realtime_hags": 0,    // Prevents freezes when VRAM is full
"nvenc_latency_over_power": 1,  // Forces high GPU power mode
"nvenc_preset": 1,              // Fast encoding, minimal GPU time
"capture": "nvfbc",             // Fastest NVIDIA capture method
"min_threads": 2                // Reduces GPU dependency with more CPU
```

These settings lower GPU scheduler priority and optimize for shared GPU usage, but **they cannot completely prevent conflicts** with applications that demand exclusive GPU access.

---

## Reporting New Conflicts

If you discover a new application that causes GPU conflicts with Sunshine:

1. **Document the incident**:
   - Application name and version
   - Symptoms (freeze, stutter, crash)
   - Logs from `journalctl -u sunshine -n 200`
   - GPU usage from `nvidia-smi` if available

2. **Add to this list** via pull request or issue

3. **Share with Sunshine community**:
   - https://github.com/LizardByte/Sunshine/issues
   - Include "NVENC conflict" in title

---

## References

- Sunshine GPU Configuration: `/config/sunshine-config.json`
- Troubleshooting Guide: `/recovery/troubleshooting-card.md`
- Incident Report: `/home/andrea/Documents/claude-sunshine-issues.md`
- Sunshine Documentation: https://docs.lizardbyte.dev/projects/sunshine/

**Last Updated:** 2025-11-14
**Incident Reference:** PC freeze on 2025-11-14 (Claude Desktop + Sunshine conflict)
