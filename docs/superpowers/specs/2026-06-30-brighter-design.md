# Brighter — Design Spec

**Date:** 2026-06-30
**Status:** Approved

## Overview

Brighter is a macOS menu bar app that extends display brightness beyond the system maximum on HDR-capable displays. It works by manipulating gamma tables to push RGB values above 1.0, leveraging the HDR headroom available on Apple's XDR displays. When the user presses the brightness-up key at maximum system brightness, Brighter intercepts the keypress and continues boosting brightness further, providing a seamless experience that feels like a native macOS feature.

## Target Hardware

- MacBook Pro 14" and 16" (2021+) with XDR display
- Pro Display XDR
- Apple Studio Display
- Any future macOS display with HDR headroom above SDR white

Non-HDR displays will show a clear "not supported" message. No SDR fallback overlay is provided.

## Architecture

### App Type

Menu bar-only app (no dock icon, no main window). Uses SwiftUI for UI and AppKit for system-level operations.

### Components

| Component | Responsibility |
|-----------|---------------|
| `BrightnessEngine` | Gamma table calculations and application to displays |
| `KeyMonitor` | IOKit/CoreGraphics event tap for brightness key detection |
| `DisplayManager` | HDR display detection, system brightness monitoring |
| `BrightnessHUD` | Custom OSD overlay showing boosted brightness level |
| `MenuBarController` | Menu bar icon, slider, and menu items |
| `SettingsManager` | Persisted preferences (launch at login, max boost, etc.) |

### Data Flow

```
User presses F2 (brightness up) at max brightness
  → KeyMonitor detects event, blocks propagation
  → BrightnessEngine increments boost factor
  → GammaTable calculates new RGB lookup table
  → CGDisplaySetGammaTable applies to display
  → BrightnessHUD shows visual feedback
  → MenuBarController updates icon

User presses F1 (brightness down) with boost active
  → KeyMonitor detects event
  → BrightnessEngine decrements boost factor
  → If boost reaches 1.0, event propagates to system (returns to normal brightness control)
  → If boost > 1.0, event is consumed, new gamma table applied
  → BrightnessHUD shows visual feedback
```

## Core Technical Details

### Gamma Table Manipulation

macOS HDR displays have luminance headroom above SDR white (1.0). The gamma lookup table maps input pixel values to output luminance. By modifying this table, we can push values above 1.0 into the HDR range.

**Default gamma table:** Linear ramp where `output[i] = i / 255`
**Boosted gamma table:** `output[i] = (i / 255) * boostFactor` where boostFactor ranges from 1.0 to 1.6

The boost is applied in discrete steps (matching the 16 steps macOS uses for normal brightness), giving approximately 10 additional brightness levels beyond the system maximum.

**Key constraint:** Gamma tables must be applied per-display. If the system brightness changes (e.g., auto-brightness), the gamma table is reset and must be re-applied.

### Key Monitoring

Uses `CGEventTap` from CoreGraphics to intercept brightness key events:

1. Create event tap for `keyDown` events
2. Filter for brightness key codes (key code 107 for brightness up, 113 for brightness down on Apple keyboards)
3. At max system brightness with brightness-up: consume the event and increment boost
4. With boost active and brightness-down: consume the event and decrement boost
5. At boost 1.0 with brightness-down: let event propagate to system

Requires Accessibility permission (System Settings → Privacy & Security → Accessibility). App provides guided setup on first launch.

### HDR Display Detection

Multiple detection strategies for robustness:

1. Query `CoreDisplay` capabilities for extended luminance support
2. Check display `CGDisplayMode` for HDR/P3 color space
3. Read IOKit display properties for peak luminance values
4. Fallback: check display model against known HDR-capable models

### System Brightness Monitoring

Monitor the system brightness level to know when we're at maximum:

1. Use `DisplayServicesGetBrightness()` to read current brightness
2. Poll periodically (every 0.5s) or react to `NSWorkspace` notifications
3. When system brightness drops below 1.0, disable boost and reset gamma tables
4. When system brightness returns to 1.0, re-apply boost if it was previously active

## UI Design

### Menu Bar

- **Icon:** SF Symbol `sun.max` — opacity/size changes with boost level
- **Click:** Dropdown panel with:
  - Current brightness indicator with extended slider (0% → 100% → 160%)
  - "Enable Boost" toggle
  - Separator
  - "Start at Login" checkbox
  - "About Brighter" link
  - "Quit Brighter"
- **Scroll on icon:** Adjusts brightness/boost (matching macOS volume-scroll behavior)

### Brightness HUD

When boost changes via keyboard:

1. Translucent overlay appears near top-center of screen
2. Shows sun icon with brightness bars — standard macOS shows 16 bars, Brighter shows bars beyond 16
3. Boosted bars are tinted amber/gold to distinguish from normal brightness
4. Auto-fades after 1.5 seconds
5. Rounded corners, backdrop blur, matching macOS aesthetic

### First-Run Experience

1. Welcome screen explaining what Brighter does
2. HDR display check with result
3. Accessibility permission request with step-by-step instructions
4. Quick demo — "Try pressing your brightness-up key now!"

## Settings & Persistence

Stored via `UserDefaults`:

- `boostEnabled: Bool` — whether boost is active
- `boostFactor: Double` — current boost level (1.0–1.6)
- `launchAtLogin: Bool` — uses `SMAppService` on macOS 13+
- `maxBoost: Double` — user-configurable maximum (default 1.6)
- `perDisplayBoost: [CGDirectDisplayID: Double]` — per-display settings for multi-monitor

## Error Handling

| Scenario | Response |
|----------|----------|
| No HDR display detected | Friendly message in menu bar, boost controls disabled |
| Accessibility permission not granted | Step-by-step guide to System Settings, limited functionality until granted |
| Display disconnect while boosted | Detect via `NSWorkspace` notification, reset gamma tables for disconnected display |
| Display reconnect | Re-apply saved boost settings if applicable |
| System brightness changes while boosted | Re-apply gamma table after system brightness settles |
| App quit/crash | Reset all gamma tables to defaults in `deinit` and via signal handlers |
| Gamma table API fails | Log error, fall back gracefully, notify user |

## Technical Stack

| Technology | Usage |
|-----------|-------|
| Swift 5.9+ | Primary language |
| SwiftUI | Menu bar UI, HUD overlay |
| AppKit | Event tap, gamma table manipulation, window management |
| CoreGraphics | `CGDisplaySetGammaTable`, display queries |
| IOKit | Low-level display services |
| Combine | Event streams between components |
| SF Symbols | Icon system |
| XCTests | Unit tests for gamma table math and engine logic |

## Project Structure

```
Brighter/
├── Brighter.xcodeproj
├── Brighter/
│   ├── App/
│   │   ├── BrighterApp.swift
│   │   └── AppDelegate.swift
│   ├── Engine/
│   │   ├── BrightnessEngine.swift
│   │   ├── DisplayManager.swift
│   │   └── KeyMonitor.swift
│   ├── UI/
│   │   ├── MenuBarController.swift
│   │   ├── MenuBarView.swift
│   │   ├── BrightnessSlider.swift
│   │   └── BrightnessHUD.swift
│   ├── Models/
│   │   ├── DisplayInfo.swift
│   │   └── BrightnessState.swift
│   ├── Utilities/
│   │   ├── GammaTable.swift
│   │   ├── PermissionsHelper.swift
│   │   └── Constants.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── BrighterTests/
│   ├── GammaTableTests.swift
│   ├── BrightnessEngineTests.swift
│   └── DisplayManagerTests.swift
└── README.md
```

## Constraints & Non-Goals

- **No SDR display support** — gamma manipulation above 1.0 only works on HDR displays
- **No color temperature adjustment** — that's a different product (like f.lux/Night Shift)
- **No external display brightness control via DDC/CI** — that's a separate feature
- **macOS 13+ (Ventura) minimum** — for `SMAppService` and modern SwiftUI menu bar APIs
- **No kernel extensions** — entirely userspace via CoreGraphics/IOKit APIs
