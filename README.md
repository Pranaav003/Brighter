# ☀️ Brighter

A macOS menu bar app that extends display brightness beyond the system maximum on HDR-capable displays.

<img src="https://img.shields.io/badge/macOS-13%2B-blue" /> <img src="https://img.shields.io/badge/Swift-5.9-orange" /> <img src="https://img.shields.io/badge/license-MIT-green" />

## How It Works

macOS HDR displays have luminance headroom above SDR white (1.0×). Brighter manipulates the display's gamma lookup table via `CGSetDisplayTransferByTable` to push RGB values above 1.0, using a smoothstep curve that concentrates the boost in highlights while keeping shadows and midtones natural. This produces **real physical brightness** — not a contrast shift.

```
output = input + headroom × smoothstep(input)
```

- Blacks stay black (output=0 at input=0)
- Midtones barely change
- Whites go into HDR headroom (up to 200% of SDR white)

## Requirements

- macOS 13+ (Ventura or later)
- HDR-capable display (MacBook Pro XDR, Pro Display XDR, Studio Display)
- Swift 5.9+

## Quick Start

```bash
git clone https://github.com/Pranaav003/Brighter.git
cd Brighter
./setup.sh
```

## Usage

1. Launch Brighter — a sun icon (☀) appears in the menu bar
2. Click the sun icon to open the control panel
3. Drag the slider from 100% up to 200%
4. To reset: slide back to 100%, toggle off, or quit

## Architecture

| Component | Responsibility |
|-----------|---------------|
| `BrightnessEngine` | Boost state, gamma table application via CoreGraphics |
| `DisplayManager` | HDR display detection, system brightness reading |
| `GammaTable` | Pure math — Hermite smoothstep curve (3t²−2t³) |
| `MenuBarController` | Menu bar sun icon with popover slider |
| `BrightnessHUD` | OSD-style overlay showing boost level |

## License

MIT
