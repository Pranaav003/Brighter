# ☀️ Brighter

A macOS menu bar app that extends display brightness beyond the system maximum on HDR-capable displays.

<img src="https://img.shields.io/badge/macOS-13%2B-blue" /> <img src="https://img.shields.io/badge/Swift-5.9-orange" /> <img src="https://img.shields.io/badge/license-MIT-green" />

## How It Works

MacBook Pro and Pro Display XDR screens can produce far more light than the standard brightness slider allows — Apple reserves this extra luminance for HDR content. Brighter unlocks that headroom for the entire display, pushing real physical brightness up to 200% of the normal maximum.

The display genuinely emits more light (up to ~1600 nits on XDR panels). This is not a contrast or color trick — it's the same technology that makes HDR video look bright, applied to your whole screen.

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
| `BrightnessEngine` | Manages boost level and applies it to the display |
| `DisplayManager` | Detects HDR displays, reads system brightness |
| `GammaTable` | Math for the brightness curve (natural-looking increase) |
| `MenuBarController` | Menu bar sun icon with popover slider |
| `BrightnessHUD` | OSD-style overlay showing boost level |

## License

MIT
