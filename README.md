# ☀️ Brighter

A macOS menu bar app that extends display brightness beyond the system maximum on HDR-capable displays.

<img src="https://img.shields.io/badge/macOS-13%2B-blue" /> <img src="https://img.shields.io/badge/Swift-5.9-orange" /> <img src="https://img.shields.io/badge/license-MIT-green" />

## Requirements

- **macOS 13+** (Ventura or later)
- **HDR-capable display** — one of:
  - MacBook Pro 14" (2021+)
  - MacBook Pro 16" (2021+)
  - Apple Studio Display
  - Pro Display XDR

Non-HDR displays are not supported. Brighter relies on the HDR headroom above SDR white that only these panels provide.

## How It Works

macOS HDR displays have luminance "headroom" above SDR white (1.0×). Brighter manipulates the display's gamma lookup table via `CGSetDisplayTransferByTable` to push RGB values above 1.0, using that headroom to make the display brighter than the normal maximum.

When you press the brightness-up key (F2) at maximum system brightness, Brighter intercepts the keypress and continues boosting brightness further — up to 160% of SDR white. The experience is seamless: the brightness-up key simply keeps going past where it normally stops.

## Features

- 🌞 **Extended brightness** — up to 160% of SDR white (~10 additional brightness steps)
- ⌨️ **Brightness key integration** — works with existing F1/F2 keys, no new keybindings needed
- 📊 **Custom HUD overlay** — shows boosted brightness level with amber-tinted bars, matching the macOS OSD aesthetic
- 🎛️ **Menu bar control** — slider, toggle, and quick access from the menu bar
- 🔄 **Scroll to adjust** — scroll on the menu bar icon for fine control
- 🚀 **Launch at login** — optional, via macOS SMAppService
- 🧹 **Clean shutdown** — gamma tables are always reset on quit, even on crash (SIGTERM handler)

## Installation

### Building from Source

```bash
git clone https://github.com/user/Brighter.git
cd Brighter
swift build --configuration release
```

The built binary will be at `.build/release/Brighter`.

### Running

```bash
swift run
# or
.build/release/Brighter
```

On first launch, macOS will prompt you to grant Accessibility permission (required for brightness key interception). Follow the on-screen instructions to enable it in System Settings → Privacy & Security → Accessibility.

## Usage

1. **Launch Brighter** — a sun icon appears in the menu bar
2. **Set your display brightness to maximum** using the standard F2 key
3. **Keep pressing F2** — Brighter takes over and continues boosting
4. **Press F1** to decrease boost, then normal system brightness
5. **Click the menu bar icon** for a slider and settings
6. **Toggle "Enable Boost"** to quickly switch boost on/off

### Menu Bar

- **Click** the sun icon to open the control panel
- **Slider** adjusts boost from 100% to 160%
- **Toggle** enables/disables boost
- **Start at Login** adds Brighter to your login items
- **Scroll** on the menu bar icon to fine-tune brightness

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│  KeyMonitor  │────▶│ BrighterApp  │────▶│ BrightnessEngine  │
│  (CGEventTap)│     │ (AppDelegate)│     │ (boost + gamma)   │
└─────────────┘     └──────┬───────┘     └────────┬─────────┘
                           │                      │
                    ┌──────▼───────┐      ┌───────▼────────┐
                    │ BrightnessHUD│      │  GammaTable     │
                    │  (OSD overlay)│      │  (pure math)    │
                    └──────────────┘      └────────────────┘
                           │
                    ┌──────▼───────┐
                    │DisplayManager│
                    │(HDR detection│
                    │ brightness)  │
                    └──────────────┘
```

| Component | File | Responsibility |
|-----------|------|---------------|
| `BrightnessEngine` | `Engine/BrightnessEngine.swift` | Boost state management, gamma table application |
| `DisplayManager` | `Engine/DisplayManager.swift` | HDR display detection, system brightness reading |
| `KeyMonitor` | `Engine/KeyMonitor.swift` | CGEventTap for brightness key interception |
| `BrightnessHUD` | `UI/BrightnessHUD.swift` | OSD-style brightness overlay window |
| `MenuBarController` | `UI/MenuBarController.swift` | Menu bar status item and popover |
| `GammaTable` | `Utilities/GammaTable.swift` | Pure gamma table generation functions |
| `PermissionsHelper` | `Utilities/PermissionsHelper.swift` | Accessibility permission management |

## Running Tests

```bash
swift test
```

Tests cover:
- Gamma table generation (linear, boosted, validation)
- BrightnessState model (clamping, increment/decrement)
- DisplayInfo model
- BrightnessEngine logic (boost factor, clamping, reset)

> **Note:** Full Xcode (not just Command Line Tools) is required to run tests with XCTest.

## Technical Details

### Gamma Table Manipulation

A gamma lookup table maps 8-bit input values (0–255) to floating-point output values. Normally, the table maps 255 → 1.0 (SDR white). On HDR displays, values above 1.0 map to luminance in the HDR headroom.

**Default table:** `output[i] = i / 255`
**Boosted table:** `output[i] = (i / 255) × boostFactor` where boostFactor ranges from 1.0 to 1.6

The boost is applied via `CGSetDisplayTransferByTable`, the public CoreGraphics API for display transfer functions.

### Key Monitoring

Brightness key events are intercepted using `CGEvent.tapCreate` (CoreGraphics event tap). This requires Accessibility permission. When brightness-up is pressed at max system brightness, the event is consumed and boost is increased. When brightness-down is pressed with boost active, boost is decreased; once boost reaches 1.0, the event is passed through to the system.

### HDR Display Detection

Multiple detection strategies are used:
1. `NSScreen.maximumPotentialEDRValue > 1.0` (checked via `performSelector` for SDK compatibility)
2. IOKit registry properties (`SupportsHDR`, `PeakLuminance`)

### Private API Usage

Brighter uses `DisplayServicesGetBrightness` (from the private DisplayServices framework) to read the current system brightness level. This is loaded dynamically via `dlopen`/`dlsym` at runtime — there is no hard link-time dependency. This API is stable and used by many shipping brightness apps.

## Acknowledgments

Inspired by [Vivid](https://www.getvivid.app/) by Nick Moore.

## License

MIT License — see [LICENSE](LICENSE).
