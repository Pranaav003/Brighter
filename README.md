# Brighter

A macOS menu bar app that extends display brightness beyond the system maximum on HDR-capable displays.

## Requirements

- macOS 13+ (Ventura or later)
- HDR-capable display (MacBook Pro XDR, Pro Display XDR, Studio Display)

## How It Works

Brighter manipulates the display's gamma lookup table to push RGB values above 1.0, leveraging the HDR headroom available on Apple's XDR displays. When you press the brightness-up key at maximum brightness, Brighter intercepts the keypress and continues boosting brightness further.

## Features

- Extends brightness up to 160% of SDR white
- Integrates with existing brightness keys (F1/F2)
- Custom HUD overlay shows boosted brightness level
- Menu bar control with slider
- Scroll-to-adjust on menu bar icon
- Launch at login support

## Building

```bash
swift build
```

## Running Tests

```bash
swift test
```
