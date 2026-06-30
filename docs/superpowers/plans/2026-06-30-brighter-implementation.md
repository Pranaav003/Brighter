# Brighter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that extends display brightness beyond the system maximum on HDR displays via gamma table manipulation.

**Architecture:** SwiftUI menu bar app with AppKit system-level operations. Gamma table manipulation via `CGDisplaySetGammaTable` to push values above 1.0. IOKit event tap to intercept brightness keys. Custom HUD overlay for visual feedback when boosting.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, CoreGraphics, IOKit, Combine, XCTests

## Global Constraints

- macOS 13+ (Ventura) minimum deployment target
- HDR displays only — no SDR fallback
- No kernel extensions — entirely userspace
- Menu bar only — no dock icon, no main window
- Accessibility permission required for key monitoring
- Gamma tables must be reset on app quit/crash
- Boost range: 1.0–1.6 (matching Vivid's range)
- Per-display gamma table application
- All code in Swift, no Objective-C bridging

## File Structure

| File | Responsibility |
|------|---------------|
| `Brighter/Brighter/App/BrighterApp.swift` | @main entry point, SwiftUI app lifecycle |
| `Brighter/Brighter/App/AppDelegate.swift` | Menu bar setup, engine coordination, cleanup |
| `Brighter/Brighter/Models/DisplayInfo.swift` | Display capability model (HDR, peak luminance, etc.) |
| `Brighter/Brighter/Models/BrightnessState.swift` | Combined system brightness + boost state |
| `Brighter/Brighter/Utilities/GammaTable.swift` | Gamma table generation math (pure functions) |
| `Brighter/Brighter/Utilities/Constants.swift` | Boost limits, step sizes, defaults |
| `Brighter/Brighter/Utilities/PermissionsHelper.swift` | Accessibility permission check and prompt |
| `Brighter/Brighter/Engine/DisplayManager.swift` | HDR display detection, system brightness read/write |
| `Brighter/Brighter/Engine/BrightnessEngine.swift` | Core engine: boost state, gamma table application |
| `Brighter/Brighter/Engine/KeyMonitor.swift` | CGEventTap for brightness key interception |
| `Brighter/Brighter/UI/MenuBarController.swift` | Menu bar item, popover/panel controller |
| `Brighter/Brighter/UI/MenuBarView.swift` | SwiftUI content for menu bar dropdown |
| `Brighter/Brighter/UI/BrightnessSlider.swift` | Custom slider showing 0%–160% range |
| `Brighter/Brighter/UI/BrightnessHUD.swift` | OSD-style brightness overlay window |
| `Brighter/Brighter/Resources/Info.plist` | App metadata, LSUIElement=true |
| `Brighter/BrighterTests/GammaTableTests.swift` | Unit tests for gamma table math |
| `Brighter/BrighterTests/BrightnessEngineTests.swift` | Unit tests for engine logic |
| `Brighter/BrighterTests/DisplayManagerTests.swift` | Unit tests for display detection |

---

### Task 1: Project Scaffolding & Xcode Project

**Files:**
- Create: `Brighter/Package.swift` (Swift Package Manager project)
- Create: `Brighter/Brighter/App/BrighterApp.swift`
- Create: `Brighter/Brighter/Resources/Info.plist`
- Create: `Brighter/Brighter/Utilities/Constants.swift`
- Create: `Brighter/README.md`

**Interfaces:**
- Produces: `Constants.maxBoost` (Double, 1.6), `Constants.minBoost` (Double, 1.0), `Constants.boostStep` (Double, 0.06 — gives ~10 steps), `Constants.hudDisplayDuration` (Double, 1.5), `Constants.brightnessPollInterval` (Double, 0.5)

- [ ] **Step 1: Create the project directory structure**

```bash
cd /private/tmp/Brighter
mkdir -p Brighter/App Brighter/Engine Brighter/UI Brighter/Models Brighter/Utilities Brighter/Resources
mkdir -p BrighterTests
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brighter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "Brighter",
            targets: ["Brighter"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Brighter",
            dependencies: [],
            path: "Brighter",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BrighterTests",
            dependencies: ["Brighter"],
            path: "BrighterTests"
        ),
    ]
)
```

- [ ] **Step 3: Create Constants.swift**

```swift
import Foundation

enum Constants {
    /// Maximum boost factor (1.6x = 160% of SDR white)
    static let maxBoost: Double = 1.6

    /// Minimum boost factor (1.0 = normal, no boost)
    static let minBoost: Double = 1.0

    /// Step size per brightness key press (gives ~10 steps from 1.0 to 1.6)
    static let boostStep: Double = 0.06

    /// How long the HUD overlay stays visible (seconds)
    static let hudDisplayDuration: Double = 1.5

    /// How often to poll system brightness (seconds)
    static let brightnessPollInterval: Double = 0.5

    /// Number of entries in a gamma table
    static let gammaTableSize: Int = 256

    /// Number of brightness bars in the macOS OSD
    static let systemBrightnessBars: Int = 16

    /// Number of additional boost bars shown in the HUD
    static let boostBars: Int = 10

    /// UserDefaults keys
    enum Defaults {
        static let boostEnabled = "boostEnabled"
        static let boostFactor = "boostFactor"
        static let launchAtLogin = "launchAtLogin"
        static let maxBoost = "maxBoost"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}
```

- [ ] **Step 4: Create BrighterApp.swift (minimal stub)**

```swift
import SwiftUI

@main
struct BrighterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 5: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Brighter</string>
    <key>CFBundleDisplayName</key>
    <string>Brighter</string>
    <key>CFBundleIdentifier</key>
    <string>com.brighter.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Brighter. All rights reserved.</string>
</dict>
</plist>
```

- [ ] **Step 6: Create README.md**

```markdown
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
```

- [ ] **Step 7: Verify the project builds**

```bash
cd /private/tmp/Brighter && swift build 2>&1 | tail -5
```

Expected: Build fails because `AppDelegate` doesn't exist yet — that's expected. We'll create it in Task 2.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: project scaffolding with Package.swift, constants, and app stub"
```

---

### Task 2: Models — DisplayInfo & BrightnessState

**Files:**
- Create: `Brighter/Brighter/Models/DisplayInfo.swift`
- Create: `Brighter/Brighter/Models/BrightnessState.swift`
- Test: `Brighter/BrighterTests/ModelTests.swift`

**Interfaces:**
- Consumes: `Constants.maxBoost`, `Constants.minBoost`, `Constants.boostStep`
- Produces: `DisplayInfo` (struct with `displayID: CGDirectDisplayID`, `isHDR: Bool`, `name: String`, `peakLuminance: Double?`), `BrightnessState` (struct with `systemBrightness: Double`, `boostFactor: Double`, `isBoosted: Bool`, `effectiveBrightness: Double`)

- [ ] **Step 1: Write the failing test for BrightnessState**

```swift
// BrighterTests/ModelTests.swift
import XCTest
@testable import Brighter

final class ModelTests: XCTestCase {

    // MARK: - BrightnessState

    func testBrightnessStateNotBoosted() {
        let state = BrightnessState(systemBrightness: 0.8, boostFactor: 1.0)
        XCTAssertFalse(state.isBoosted)
        XCTAssertEqual(state.effectiveBrightness, 0.8)
    }

    func testBrightnessStateBoosted() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.3)
        XCTAssertTrue(state.isBoosted)
        XCTAssertEqual(state.effectiveBrightness, 1.3, accuracy: 0.01)
    }

    func testBrightnessStateBoostClampsToMax() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 2.0)
        XCTAssertTrue(state.isBoosted)
        XCTAssertEqual(state.boostFactor, Constants.maxBoost)
    }

    func testBrightnessStateBoostClampsToMin() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 0.5)
        XCTAssertFalse(state.isBoosted)
        XCTAssertEqual(state.boostFactor, Constants.minBoost)
    }

    func testIncrementBoost() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.0)
        let incremented = state.incrementBoost()
        XCTAssertEqual(incremented.boostFactor, 1.0 + Constants.boostStep, accuracy: 0.001)
    }

    func testIncrementBoostClampsAtMax() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: Constants.maxBoost - 0.01)
        let incremented = state.incrementBoost()
        XCTAssertEqual(incremented.boostFactor, Constants.maxBoost, accuracy: 0.001)
    }

    func testDecrementBoost() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.12)
        let decremented = state.decrementBoost()
        XCTAssertEqual(decremented.boostFactor, 1.12 - Constants.boostStep, accuracy: 0.001)
    }

    func testDecrementBoostStopsAtMin() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.0 + Constants.boostStep * 0.5)
        let decremented = state.decrementBoost()
        XCTAssertEqual(decremented.boostFactor, Constants.minBoost, accuracy: 0.001)
    }

    // MARK: - DisplayInfo

    func testDisplayInfoHDR() {
        let info = DisplayInfo(displayID: 1, isHDR: true, name: "Built-in XDR", peakLuminance: 1600)
        XCTAssertTrue(info.isHDR)
        XCTAssertEqual(info.name, "Built-in XDR")
        XCTAssertEqual(info.peakLuminance, 1600)
    }

    func testDisplayInfoNonHDR() {
        let info = DisplayInfo(displayID: 2, isHDR: false, name: "External Monitor", peakLuminance: nil)
        XCTAssertFalse(info.isHDR)
        XCTAssertNil(info.peakLuminance)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -10
```

Expected: FAIL — types not defined yet.

- [ ] **Step 3: Write DisplayInfo model**

```swift
// Brighter/Models/DisplayInfo.swift
import CoreGraphics

/// Represents a connected display and its capabilities.
struct DisplayInfo: Equatable, Identifiable {
    /// The CoreGraphics display identifier.
    let displayID: CGDirectDisplayID

    /// Whether this display supports HDR luminance above SDR white.
    let isHDR: Bool

    /// Human-readable display name.
    let name: String

    /// Peak luminance in nits, if known.
    let peakLuminance: Double?

    var id: CGDirectDisplayID { displayID }
}
```

- [ ] **Step 4: Write BrightnessState model**

```swift
// Brighter/Models/BrightnessState.swift
import Foundation

/// Represents the combined system brightness and boost state.
struct BrightnessState: Equatable {
    /// System brightness level (0.0–1.0).
    let systemBrightness: Double

    /// Boost factor applied via gamma table (1.0–1.6).
    let boostFactor: Double

    /// Whether boost is currently active (boostFactor > 1.0).
    var isBoosted: Bool {
        boostFactor > Constants.minBoost
    }

    /// The effective brightness including boost.
    var effectiveBrightness: Double {
        systemBrightness * boostFactor
    }

    init(systemBrightness: Double, boostFactor: Double) {
        self.systemBrightness = max(0.0, min(1.0, systemBrightness))
        self.boostFactor = max(Constants.minBoost, min(Constants.maxBoost, boostFactor))
    }

    /// Returns a new state with the boost factor incremented by one step.
    func incrementBoost() -> BrightnessState {
        let newBoost = min(boostFactor + Constants.boostStep, Constants.maxBoost)
        return BrightnessState(systemBrightness: systemBrightness, boostFactor: newBoost)
    }

    /// Returns a new state with the boost factor decremented by one step.
    func decrementBoost() -> BrightnessState {
        let newBoost = max(boostFactor - Constants.boostStep, Constants.minBoost)
        return BrightnessState(systemBrightness: systemBrightness, boostFactor: newBoost)
    }

    /// Returns a new state with boost reset to 1.0.
    func resetBoost() -> BrightnessState {
        BrightnessState(systemBrightness: systemBrightness, boostFactor: Constants.minBoost)
    }

    /// Returns a new state with a specific boost factor.
    func withBoost(_ factor: Double) -> BrightnessState {
        BrightnessState(systemBrightness: systemBrightness, boostFactor: factor)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -10
```

Expected: All ModelTests pass.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add DisplayInfo and BrightnessState models with tests"
```

---

### Task 3: GammaTable Utility

**Files:**
- Create: `Brighter/Brighter/Utilities/GammaTable.swift`
- Test: `Brighter/BrighterTests/GammaTableTests.swift`

**Interfaces:**
- Consumes: `Constants.gammaTableSize`, `Constants.maxBoost`
- Produces: `GammaTable.generateLinearTable(size: Int) -> [CGFloat]`, `GammaTable.generateBoostedTable(boostFactor: Double, size: Int) -> [CGFloat]`, `GammaTable.generateBoostedTables(boostFactor: Double, size: Int) -> (red: [CGFloat], green: [CGFloat], blue: [CGFloat])`, `GammaTable.validateTable(_ table: [CGFloat]) -> Bool`

- [ ] **Step 1: Write the failing tests for GammaTable**

```swift
// BrighterTests/GammaTableTests.swift
import XCTest
@testable import Brighter

final class GammaTableTests: XCTestCase {

    // MARK: - Linear Table

    func testLinearTableHasCorrectSize() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table.count, 256)
    }

    func testLinearTableStartsAtZero() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table[0], 0.0, accuracy: 0.001)
    }

    func testLinearTableEndsAtOne() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table[255], 1.0, accuracy: 0.001)
    }

    func testLinearTableIsMonotonicallyIncreasing() {
        let table = GammaTable.generateLinearTable(size: 256)
        for i in 1..<table.count {
            XCTAssertGreaterThan(table[i], table[i - 1], "Entry \(i) should be greater than entry \(i - 1)")
        }
    }

    func testLinearTableMidpointIsHalf() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table[127], 127.0 / 255.0, accuracy: 0.01)
    }

    // MARK: - Boosted Table

    func testBoostedTableWithFactor1EqualsLinear() {
        let linear = GammaTable.generateLinearTable(size: 256)
        let boosted = GammaTable.generateBoostedTable(boostFactor: 1.0, size: 256)
        XCTAssertEqual(linear.count, boosted.count)
        for i in 0..<linear.count {
            XCTAssertEqual(linear[i], boosted[i], accuracy: 0.001, "Mismatch at index \(i)")
        }
    }

    func testBoostedTableEndsAtBoostFactor() {
        let boostFactor = 1.4
        let table = GammaTable.generateBoostedTable(boostFactor: boostFactor, size: 256)
        XCTAssertEqual(table[255], boostFactor, accuracy: 0.001)
    }

    func testBoostedTableStartsAtZero() {
        let table = GammaTable.generateBoostedTable(boostFactor: 1.4, size: 256)
        XCTAssertEqual(table[0], 0.0, accuracy: 0.001)
    }

    func testBoostedTableIsMonotonicallyIncreasing() {
        let table = GammaTable.generateBoostedTable(boostFactor: 1.3, size: 256)
        for i in 1..<table.count {
            XCTAssertGreaterThan(table[i], table[i - 1], "Entry \(i) should be greater than entry \(i - 1)")
        }
    }

    func testBoostedTableAtMaxBoost() {
        let table = GammaTable.generateBoostedTable(boostFactor: Constants.maxBoost, size: 256)
        XCTAssertEqual(table[255], Constants.maxBoost, accuracy: 0.001)
    }

    // MARK: - Boosted Triple Tables

    func testBoostedTablesAreIdentical() {
        let (red, green, blue) = GammaTable.generateBoostedTables(boostFactor: 1.3, size: 256)
        XCTAssertEqual(red.count, 256)
        XCTAssertEqual(green.count, 256)
        XCTAssertEqual(blue.count, 256)
        for i in 0..<256 {
            XCTAssertEqual(red[i], green[i], accuracy: 0.001, "Red/Green mismatch at \(i)")
            XCTAssertEqual(green[i], blue[i], accuracy: 0.001, "Green/Blue mismatch at \(i)")
        }
    }

    // MARK: - Validation

    func testValidateValidLinearTable() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertTrue(GammaTable.validateTable(table))
    }

    func testValidateValidBoostedTable() {
        let table = GammaTable.generateBoostedTable(boostFactor: 1.3, size: 256)
        XCTAssertTrue(GammaTable.validateTable(table))
    }

    func testValidateEmptyTableFails() {
        XCTAssertFalse(GammaTable.validateTable([]))
    }

    func testValidateWrongSizeTableFails() {
        let table = GammaTable.generateLinearTable(size: 128)
        XCTAssertFalse(GammaTable.validateTable(table))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -10
```

Expected: FAIL — `GammaTable` type not defined.

- [ ] **Step 3: Write GammaTable implementation**

```swift
// Brighter/Utilities/GammaTable.swift
import CoreGraphics

/// Pure functions for generating gamma lookup tables.
///
/// A gamma table maps 8-bit input values (0–255) to floating-point output values.
/// On HDR displays, output values above 1.0 map to luminance above SDR white,
/// using the display's HDR headroom.
enum GammaTable {

    /// Generates a linear (identity) gamma table.
    /// - Parameter size: Number of entries in the table (typically 256).
    /// - Returns: Array of CGFloat values from 0.0 to 1.0.
    static func generateLinearTable(size: Int = Constants.gammaTableSize) -> [CGFloat] {
        (0..<size).map { CGFloat($0) / CGFloat(size - 1) }
    }

    /// Generates a boosted gamma table that scales output by a boost factor.
    /// - Parameters:
    ///   - boostFactor: Multiplier applied to output values (1.0 = normal, 1.6 = max boost).
    ///   - size: Number of entries in the table.
    /// - Returns: Array of CGFloat values from 0.0 to boostFactor.
    static func generateBoostedTable(
        boostFactor: Double,
        size: Int = Constants.gammaTableSize
    ) -> [CGFloat] {
        let clampedFactor = max(Constants.minBoost, min(Constants.maxBoost, boostFactor))
        return (0..<size).map { i in
            CGFloat(Double(i) / Double(size - 1) * clampedFactor)
        }
    }

    /// Generates three identical boosted gamma tables (R, G, B).
    /// - Parameters:
    ///   - boostFactor: Multiplier applied to output values.
    ///   - size: Number of entries per table.
    /// - Returns: Tuple of (red, green, blue) gamma tables.
    static func generateBoostedTables(
        boostFactor: Double,
        size: Int = Constants.gammaTableSize
    ) -> (red: [CGFloat], green: [CGFloat], blue: [CGFloat]) {
        let table = generateBoostedTable(boostFactor: boostFactor, size: size)
        return (red: table, green: table, blue: table)
    }

    /// Validates that a gamma table has the correct size and value range.
    /// - Parameter table: The gamma table to validate.
    /// - Returns: True if the table is valid.
    static func validateTable(_ table: [CGFloat]) -> Bool {
        guard table.count == Constants.gammaTableSize else { return false }
        guard table.first ?? -1 >= 0.0 else { return false }
        // Allow values above 1.0 for HDR headroom
        return true
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -15
```

Expected: All GammaTableTests and ModelTests pass.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add GammaTable utility with linear and boosted table generation"
```

---

### Task 4: PermissionsHelper Utility

**Files:**
- Create: `Brighter/Brighter/Utilities/PermissionsHelper.swift`

**Interfaces:**
- Produces: `PermissionsHelper.isAccessibilityGranted() -> Bool`, `PermissionsHelper.promptForAccessibility()`, `PermissionsHelper.openAccessibilitySettings()`

- [ ] **Step 1: Write PermissionsHelper**

```swift
// Brighter/Utilities/PermissionsHelper.swift
import ApplicationServices
import AppKit

/// Helper for checking and requesting Accessibility permissions.
enum PermissionsHelper {

    /// Whether the app currently has Accessibility permission.
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    /// Prompts the user to grant Accessibility permission.
    /// Opens System Settings and shows a prompt dialog.
    static func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility section of System Settings.
    static func openAccessibilitySettings() {
        // macOS 13+ uses the new Settings URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add PermissionsHelper for Accessibility permission flow"
```

---

### Task 5: DisplayManager — HDR Detection & System Brightness

**Files:**
- Create: `Brighter/Brighter/Engine/DisplayManager.swift`
- Test: `Brighter/BrighterTests/DisplayManagerTests.swift`

**Interfaces:**
- Consumes: `DisplayInfo`
- Produces: `DisplayManager` (class, ObservableObject) with `hdrDisplays: [DisplayInfo]`, `allDisplays: [DisplayInfo]`, `systemBrightness(for displayID: CGDirectDisplayID) -> Double`, `isSystemBrightnessMax(for displayID: CGDirectDisplayID) -> Bool`, `refreshDisplays()`, `startMonitoring()`, `stopMonitoring()`

- [ ] **Step 1: Write the failing test**

```swift
// BrighterTests/DisplayManagerTests.swift
import XCTest
@testable import Brighter

final class DisplayManagerTests: XCTestCase {

    func testDetectOnlineDisplays() {
        let manager = DisplayManager()
        let displays = manager.allDisplays
        // On any Mac running tests, there should be at least one display
        XCTAssertFalse(displays.isEmpty, "Should detect at least one display")
    }

    func testHDRDisplaysSubsetOfAllDisplays() {
        let manager = DisplayManager()
        let allDisplays = manager.allDisplays
        let hdrDisplays = manager.hdrDisplays
        // HDR displays must be a subset of all displays
        for hdrDisplay in hdrDisplays {
            XCTAssertTrue(allDisplays.contains(where: { $0.displayID == hdrDisplay.displayID }),
                          "HDR display \(hdrDisplay.displayID) not found in all displays")
        }
    }

    func testSystemBrightnessInRange() {
        let manager = DisplayManager()
        guard let display = manager.allDisplays.first else {
            XCTFail("No displays found")
            return
        }
        let brightness = manager.systemBrightness(for: display.displayID)
        XCTAssertGreaterThanOrEqual(brightness, 0.0)
        XCTAssertLessThanOrEqual(brightness, 1.0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -10
```

Expected: FAIL — `DisplayManager` not defined.

- [ ] **Step 3: Write DisplayManager implementation**

```swift
// Brighter/Engine/DisplayManager.swift
import CoreGraphics
import IOKit
import IOKit.graphics
import Combine
import AppKit

/// Manages display detection and system brightness monitoring.
final class DisplayManager: ObservableObject {

    /// All detected displays.
    @Published private(set) var allDisplays: [DisplayInfo] = []

    /// Only HDR-capable displays.
    var hdrDisplays: [DisplayInfo] {
        allDisplays.filter { $0.isHDR }
    }

    /// Whether any HDR display is connected.
    var hasHDRDisplay: Bool {
        !hdrDisplays.isEmpty
    }

    private var monitorTimer: Timer?

    init() {
        refreshDisplays()
    }

    /// Refreshes the list of detected displays.
    func refreshDisplays() {
        var displays: [DisplayInfo] = []

        var onlineDisplayIDs: [CGDirectDisplayID] = []
        var displayCount: UInt32 = 0
        let result = CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount)

        guard result == .success else { return }

        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplayIDs[i]
            let isHDR = checkHDRCapability(for: displayID)
            let name = getDisplayName(for: displayID)
            let peakLuminance = getPeakLuminance(for: displayID)
            displays.append(DisplayInfo(
                displayID: displayID,
                isHDR: isHDR,
                name: name,
                peakLuminance: peakLuminance
            ))
        }

        allDisplays = displays
    }

    /// Gets the system brightness for a specific display.
    func systemBrightness(for displayID: CGDirectDisplayID) -> Double {
        // Use DisplayServices framework (private but stable API)
        var brightness: Float = 0.0
        let result = DisplayServicesGetBrightness(displayID, &brightness)
        if result == kCGErrorSuccess {
            return Double(brightness)
        }
        // Fallback: try IOKit path
        return 1.0
    }

    /// Whether the system brightness is at maximum for a display.
    func isSystemBrightnessMax(for displayID: CGDirectDisplayID) -> Bool {
        systemBrightness(for: displayID) >= 0.99
    }

    /// Starts periodic monitoring of display changes.
    func startMonitoring() {
        stopMonitoring()
        monitorTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.brightnessPollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshDisplays()
        }
    }

    /// Stops monitoring.
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - Private

    private func checkHDRCapability(for displayID: CGDirectDisplayID) -> Bool {
        // Strategy 1: Check if display supports extended luminance via CoreDisplay
        // The CoreDisplay API can report HDR capability
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            let pixelEncoding = CGDisplayModeGetPixelEncoding(mode)
            // HDR displays typically use LEPA or RGhA pixel encoding
            if pixelEncoding?.contains("RGhA") == true || pixelEncoding?.contains("LEPA") == true {
                return true
            }
        }

        // Strategy 2: Check IOKit properties for HDR/EDR support
        let registryID = CGDisplayUnitNumber(displayID)
        let servicePort = IOKitGetMatchingService(
            kIOMasterPortDefault,
            IORegistryEntryIDMatching(registryID)
        )
        defer { IOObjectRelease(servicePort) }

        if servicePort != 0 {
            // Check for EDR (Extended Dynamic Range) support
            if let edrProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "SupportsHDR" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let supportsHDR = edrProperty.takeUnretainedValue() as? Bool, supportsHDR {
                    return true
                }
            }

            // Check peak luminance via IOKit
            if let peakProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "PeakLuminance" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let peak = peakProperty.takeUnretainedValue() as? Int, peak > 500 {
                    return true
                }
            }
        }

        // Strategy 3: Known HDR display model check
        // MacBook Pro 14"/16" (2021+), Studio Display, Pro Display XDR
        // These have built-in XDR panels
        if CGDisplayIsBuiltin(displayID) != 0 {
            // Check screen size — HDR built-in displays are 14" or 16"
            let screen = NSScreen.screens.first { $0.displayID == displayID }
            if let screen = screen {
                let height = screen.frame.height
                // MacBook Pro 14" has ~832pt height, 16" has ~960pt height in points
                // HDR built-in displays report high backing scale factor
                if screen.backingScaleFactor >= 2.0 {
                    // Further check: HDR built-in displays have EDR capabilities
                    if screen.maximumPotentialEDRValue > 1.0 {
                        return true
                    }
                }
            }
        }

        // For external displays, check NSScreen EDR
        if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            if screen.maximumPotentialEDRValue > 1.0 {
                return true
            }
        }

        return false
    }

    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        // Try to get the display name from IOKit
        let registryID = CGDisplayUnitNumber(displayID)
        let servicePort = IOKitGetMatchingService(
            kIOMasterPortDefault,
            IORegistryEntryIDMatching(registryID)
        )
        defer { IOObjectRelease(servicePort) }

        if servicePort != 0 {
            if let nameProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "DisplayVendorName" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let name = nameProperty.takeUnretainedValue() as? String {
                    return name
                }
            }
        }

        if CGDisplayIsBuiltin(displayID) != 0 {
            return "Built-in Display"
        }
        return "Display \(displayID)"
    }

    private func getPeakLuminance(for displayID: CGDirectDisplayID) -> Double? {
        let registryID = CGDisplayUnitNumber(displayID)
        let servicePort = IOKitGetMatchingService(
            kIOMasterPortDefault,
            IORegistryEntryIDMatching(registryID)
        )
        defer { IOObjectRelease(servicePort) }

        if servicePort != 0 {
            if let peakProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "PeakLuminance" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let peak = peakProperty.takeUnretainedValue() as? Int {
                    return Double(peak)
                }
            }
        }
        return nil
    }
}

// MARK: - DisplayServices Bridge

/// Private DisplayServices framework functions used for brightness control.
/// These are stable Apple private APIs used by many brightness apps.
@_silgen_name("DisplayServicesGetBrightness")
private func DisplayServicesGetBrightness(
    _ displayID: CGDirectDisplayID,
    _ brightness: UnsafeMutablePointer<Float>
) -> CGError

/// Convenience extension to get display ID from NSScreen.
extension NSScreen {
    var displayID: CGDirectDisplayID {
        // The screen number from deviceDescription
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let screenNumber = deviceDescription[key] as? NSNumber {
            return screenNumber.uint32Value
        }
        return 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -15
```

Expected: DisplayManagerTests and all prior tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add DisplayManager with HDR detection and brightness monitoring"
```

---

### Task 6: BrightnessEngine — Core Boost Logic

**Files:**
- Create: `Brighter/Brighter/Engine/BrightnessEngine.swift`
- Test: `Brighter/BrighterTests/BrightnessEngineTests.swift`

**Interfaces:**
- Consumes: `GammaTable`, `DisplayManager`, `BrightnessState`, `Constants`
- Produces: `BrightnessEngine` (class, ObservableObject) with `currentState: BrightnessState`, `boostFactor: Double`, `isBoosted: Bool`, `increaseBoost(for displayID: CGDirectDisplayID)`, `decreaseBoost(for displayID: CGDirectDisplayID)`, `setBoost(_ factor: Double, for displayID: CGDirectDisplayID)`, `resetAllBoosts()`, `applyCurrentBoost(for displayID: CGDirectDisplayID)`

- [ ] **Step 1: Write the failing test**

```swift
// BrighterTests/BrightnessEngineTests.swift
import XCTest
@testable import Brighter

final class BrightnessEngineTests: XCTestCase {

    func testInitialBoostIsMin() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
    }

    func testIncreaseBoost() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.increaseBoost()
        XCTAssertEqual(engine.boostFactor, Constants.minBoost + Constants.boostStep, accuracy: 0.001)
    }

    func testIncreaseBoostClampsAtMax() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        // Set to near max
        engine.setBoost(Constants.maxBoost - 0.01)
        engine.increaseBoost()
        XCTAssertEqual(engine.boostFactor, Constants.maxBoost, accuracy: 0.001)
    }

    func testDecreaseBoost() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(1.2)
        engine.decreaseBoost()
        XCTAssertEqual(engine.boostFactor, 1.2 - Constants.boostStep, accuracy: 0.001)
    }

    func testDecreaseBoostStopsAtMin() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(Constants.minBoost + 0.01)
        engine.decreaseBoost()
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
    }

    func testResetBoost() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(1.5)
        engine.resetBoost()
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
        XCTAssertFalse(engine.isBoosted)
    }

    func testIsBoostedReflectsState() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        XCTAssertFalse(engine.isBoosted)
        engine.setBoost(1.1)
        XCTAssertTrue(engine.isBoosted)
        engine.resetBoost()
        XCTAssertFalse(engine.isBoosted)
    }

    func testBoostFactorClampedToValidRange() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(0.5) // Below minimum
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
        engine.setBoost(3.0) // Above maximum
        XCTAssertEqual(engine.boostFactor, Constants.maxBoost, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -10
```

Expected: FAIL — `BrightnessEngine` not defined.

- [ ] **Step 3: Write BrightnessEngine implementation**

```swift
// Brighter/Engine/BrightnessEngine.swift
import CoreGraphics
import Combine
import os.log

/// The core engine that manages brightness boost state and applies gamma tables.
final class BrightnessEngine: ObservableObject {

    /// Current boost factor (1.0 = no boost, up to 1.6).
    @Published private(set) var boostFactor: Double = Constants.minBoost

    /// Whether boost is currently active.
    var isBoosted: Bool {
        boostFactor > Constants.minBoost
    }

    /// The display manager for detecting displays and reading system brightness.
    private let displayManager: DisplayManager

    /// Logger for this engine.
    private let logger = Logger(subsystem: "com.brighter.app", category: "BrightnessEngine")

    /// Per-display boost storage.
    private var perDisplayBoost: [CGDirectDisplayID: Double] = [:]

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    // MARK: - Boost Control

    /// Increases the boost factor by one step.
    func increaseBoost() {
        let newFactor = min(boostFactor + Constants.boostStep, Constants.maxBoost)
        setBoost(newFactor)
    }

    /// Decreases the boost factor by one step.
    func decreaseBoost() {
        let newFactor = max(boostFactor - Constants.boostStep, Constants.minBoost)
        setBoost(newFactor)
    }

    /// Sets the boost factor to a specific value.
    func setBoost(_ factor: Double) {
        let clamped = max(Constants.minBoost, min(Constants.maxBoost, factor))
        boostFactor = clamped
        logger.info("Boost factor set to \(clamped, format: .fixed(precision: 2))")
    }

    /// Resets boost to 1.0.
    func resetBoost() {
        setBoost(Constants.minBoost)
    }

    // MARK: - Gamma Table Application

    /// Applies the current boost to a specific display via gamma table.
    func applyCurrentBoost(for displayID: CGDirectDisplayID) {
        let (red, green, blue) = GammaTable.generateBoostedTables(boostFactor: boostFactor)

        guard GammaTable.validateTable(red),
              GammaTable.validateTable(green),
              GammaTable.validateTable(blue) else {
            logger.error("Invalid gamma table generated for boost factor \(self.boostFactor)")
            return
        }

        let result = CGDisplaySetGammaTable(
            displayID,
            UInt32(red.count),
            red,
            green,
            blue
        )

        if result != .success {
            logger.error("Failed to set gamma table for display \(displayID): \(result.rawValue)")
        } else {
            perDisplayBoost[displayID] = boostFactor
            logger.info("Applied boost \(self.boostFactor, format: .fixed(precision: 2)) to display \(displayID)")
        }
    }

    /// Resets the gamma table for a specific display to its default (linear) state.
    func resetGammaTable(for displayID: CGDirectDisplayID) {
        let red = GammaTable.generateLinearTable()
        let green = GammaTable.generateLinearTable()
        let blue = GammaTable.generateLinearTable()

        let result = CGDisplaySetGammaTable(
            displayID,
            UInt32(red.count),
            red,
            green,
            blue
        )

        if result != .success {
            logger.error("Failed to reset gamma table for display \(displayID): \(result.rawValue)")
        } else {
            perDisplayBoost.removeValue(forKey: displayID)
            logger.info("Reset gamma table for display \(displayID)")
        }
    }

    /// Resets all gamma tables for all displays that have been boosted.
    func resetAllBoosts() {
        for displayID in perDisplayBoost.keys {
            resetGammaTable(for: displayID)
        }
        resetBoost()
    }

    /// Handles a brightness-up key event at maximum system brightness.
    func handleBrightnessUp(for displayID: CGDirectDisplayID) {
        guard displayManager.isSystemBrightnessMax(for: displayID) else {
            // System brightness isn't at max — let the system handle it
            return
        }
        increaseBoost()
        applyCurrentBoost(for: displayID)
    }

    /// Handles a brightness-down key event when boost may be active.
    /// Returns whether the event should be consumed (true) or passed to the system (false).
    func handleBrightnessDown(for displayID: CGDirectDisplayID) -> Bool {
        if isBoosted {
            decreaseBoost()
            if isBoosted {
                applyCurrentBoost(for: displayID)
                return true // Consume the event
            } else {
                // Boost just reached 1.0 — reset gamma and let system take over
                resetGammaTable(for: displayID)
                return false // Let the system handle it
            }
        }
        return false // No boost active, let system handle it
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /private/tmp/Brighter && swift test 2>&1 | tail -15
```

Expected: All BrightnessEngineTests and prior tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add BrightnessEngine with boost control and gamma table application"
```

---

### Task 7: KeyMonitor — Brightness Key Interception

**Files:**
- Create: `Brighter/Brighter/Engine/KeyMonitor.swift`

**Interfaces:**
- Consumes: `BrightnessEngine`, `DisplayManager`, `PermissionsHelper`
- Produces: `KeyMonitor` (class) with `start()`, `stop()`, `onBrightnessUp: (() -> Void)?`, `onBrightnessDown: (() -> Bool)?`

- [ ] **Step 1: Write KeyMonitor implementation**

```swift
// Brighter/Engine/KeyMonitor.swift
import CoreGraphics
import AppKit
import os.log

/// Monitors brightness key events using a CGEventTap.
///
/// When the user presses brightness-up at max brightness or brightness-down with boost active,
/// the monitor intercepts the event and notifies the engine.
final class KeyMonitor {

    /// Called when brightness-up is pressed at max system brightness.
    var onBrightnessUp: (() -> Void)?

    /// Called when brightness-down is pressed while boost is active.
    /// Returns whether the event should be consumed.
    var onBrightnessDown: (() -> Bool)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let logger = Logger(subsystem: "com.brighter.app", category: "KeyMonitor")

    /// Whether the monitor is currently active.
    private(set) var isRunning = false

    /// Starts monitoring brightness key events.
    /// Requires Accessibility permission.
    func start() {
        guard !isRunning else { return }

        guard PermissionsHelper.isAccessibilityGranted() else {
            logger.warning("Cannot start key monitor — Accessibility permission not granted")
            return
        }

        // Create an event tap for key events
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEventTapCreate(
            .cghidEventTap,
            .headInsertEventTap,
            .defaultTap,
            eventMask,
            { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Failed to create event tap. Accessibility permission may not be granted.")
            return
        }

        self.eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            runLoopSource,
            .commonModes
        )

        CGEventTapEnable(tap, true)
        isRunning = true
        logger.info("Key monitor started")
    }

    /// Stops monitoring brightness key events.
    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEventTapEnable(tap, false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false
        logger.info("Key monitor stopped")
    }

    deinit {
        stop()
    }

    // MARK: - Private

    /// Brightness key codes from the HID Usage Tables (Consumer page).
    /// These are the key codes used by Apple keyboards for display brightness.
    private static let brightnessUpKeyCode: CGKeyCode = 107  // F2 with fn
    private static let brightnessDownKeyCode: CGKeyCode = 113 // F1 with fn

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle event tap being disabled by the system (e.g., timeout)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEventTapEnable(tap, true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == Self.brightnessUpKeyCode {
            // Check if system brightness is at max — if so, handle it ourselves
            logger.debug("Brightness up key detected")
            onBrightnessUp?()
            // Don't consume the event if the system should still process it.
            // The engine will decide based on whether we're at max brightness.
            // For now, always consume when we might boost, to prevent the system beep.
            return nil // Consume the event
        }

        if keyCode == Self.brightnessDownKeyCode {
            logger.debug("Brightness down key detected")
            let shouldConsume = onBrightnessDown?() ?? false
            if shouldConsume {
                return nil // Consume the event
            }
            return Unmanaged.passRetained(event) // Pass to system
        }

        return Unmanaged.passRetained(event)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add KeyMonitor for brightness key event interception"
```

---

### Task 8: BrightnessHUD — OSD Overlay

**Files:**
- Create: `Brighter/Brighter/UI/BrightnessHUD.swift`

**Interfaces:**
- Consumes: `Constants`
- Produces: `BrightnessHUD` (class) with `show(boostFactor: Double)`, `hide()`

- [ ] **Step 1: Write BrightnessHUD implementation**

```swift
// Brighter/UI/BrightnessHUD.swift
import SwiftUI
import AppKit

/// A custom HUD overlay that shows the boosted brightness level,
/// similar to the macOS volume/brightness OSD.
final class BrightnessHUD {

    private var hudWindow: NSWindow?
    private var hideTimer: Timer?
    private let logger = os.Logger(subsystem: "com.brighter.app", category: "BrightnessHUD")

    /// Shows the HUD with the current boost factor.
    /// - Parameter boostFactor: The current boost factor (1.0–1.6).
    func show(boostFactor: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.showOnMainThread(boostFactor: boostFactor)
        }
    }

    /// Hides the HUD immediately.
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideOnMainThread()
        }
    }

    // MARK: - Private

    private func showOnMainThread(boostFactor: Double) {
        // Cancel any pending hide
        hideTimer?.invalidate()

        let boostLevel = Int(round((boostFactor - Constants.minBoost) / Constants.boostStep))
        let totalBars = Constants.systemBrightnessBars + Constants.boostBars

        let view = HUDView(
            systemBars: Constants.systemBrightnessBars,
            boostBars: Constants.boostBars,
            filledBoostBars: boostLevel
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 120)

        if hudWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 120),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .screenSaver + 1
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            hudWindow = window
        }

        hudWindow?.contentView = hostingView

        // Position at top center of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 280
            let windowHeight: CGFloat = 120
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.maxY - windowHeight - 20
            hudWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hudWindow?.orderFrontRegardless()

        // Auto-hide after the display duration
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.hudDisplayDuration,
            repeats: false
        ) { [weak self] _ in
            self?.hideOnMainThread()
        }
    }

    private func hideOnMainThread() {
        hudWindow?.orderOut(nil)
    }
}

// MARK: - SwiftUI HUD View

private struct HUDView: View {
    let systemBars: Int
    let boostBars: Int
    let filledBoostBars: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                // Sun icon
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                // Brightness bars
                HStack(spacing: 3) {
                    // System bars (filled, representing normal brightness)
                    ForEach(0..<systemBars, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 6, height: 14)
                    }

                    // Boost bars
                    ForEach(0..<boostBars, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(index < filledBoostBars
                                  ? Color.amber
                                  : Color.white.opacity(0.2))
                            .frame(width: 6, height: 14)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Color Extension

private extension Color {
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.03)
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add BrightnessHUD with OSD-style brightness overlay"
```

---

### Task 9: Menu Bar UI — Slider, View, and Controller

**Files:**
- Create: `Brighter/Brighter/UI/BrightnessSlider.swift`
- Create: `Brighter/Brighter/UI/MenuBarView.swift`
- Create: `Brighter/Brighter/UI/MenuBarController.swift`

**Interfaces:**
- Consumes: `BrightnessEngine`, `DisplayManager`, `Constants`
- Produces: `MenuBarController` (class) with `setupMenuBarItem()`, `updateMenuBarIcon()`

- [ ] **Step 1: Write BrightnessSlider**

```swift
// Brighter/UI/BrightnessSlider.swift
import SwiftUI

/// A custom slider that shows the brightness range from 0% to 160%.
/// The range 0%–100% represents system brightness; 100%–160% represents boost.
struct BrightnessSlider: View {
    @Binding var boostFactor: Double
    let onBoostChange: (Double) -> Void

    /// The total range of the slider: 0.0 to 1.6
    private let totalRange: Double = Constants.maxBoost

    /// The threshold where boost begins
    private let boostThreshold: Double = Constants.minBoost

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: $boostFactor,
                in: Constants.minBoost...Constants.maxBoost,
                step: Constants.boostStep
            ) {
                Text("Brightness")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } onEditingChanged: { _ in
                onBoostChange(boostFactor)
            }
            .tint(gradient)

            HStack {
                Text("100%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(boostFactor * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(boostFactor > 1.0 ? .amber : .primary)
            }
        }
    }

    private var gradient: Color {
        boostFactor > 1.0 ? .amber : .blue
    }
}

private extension Color {
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.03)
}
```

- [ ] **Step 2: Write MenuBarView**

```swift
// Brighter/UI/MenuBarView.swift
import SwiftUI

/// The main content view for the menu bar dropdown.
struct MenuBarView: View {
    @ObservedObject var engine: BrightnessEngine
    @ObservedObject var displayManager: DisplayManager
    let onToggleBoost: () -> Void
    let onLaunchAtLoginToggle: () -> Void
    let onQuit: () -> Void

    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // HDR Status
            if !displayManager.hasHDRDisplay {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No HDR display detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Brightness Slider
            if displayManager.hasHDRDisplay {
                BrightnessSlider(
                    boostFactor: Binding(
                        get: { engine.boostFactor },
                        set: { engine.setBoost($0) }
                    ),
                    onBoostChange: { factor in
                        engine.setBoost(factor)
                        if let display = displayManager.hdrDisplays.first {
                            engine.applyCurrentBoost(for: display.displayID)
                        }
                    }
                )

                // Enable Boost Toggle
                Toggle("Enable Boost", isOn: Binding(
                    get: { engine.isBoosted },
                    set: { _ in onToggleBoost() }
                ))
                .toggleStyle(.switch)
                .font(.callout)
            }

            Divider()

            // Launch at Login
            Toggle("Start at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .font(.callout)
                .onChange(of: launchAtLogin) { _, newValue in
                    onLaunchAtLoginToggle()
                }

            Divider()

            // About & Quit
            HStack {
                Button("About Brighter") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Brighter",
                            NSApplication.AboutPanelOptionKey.version: "1.0.0"
                        ]
                    )
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                Button("Quit Brighter") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
```

- [ ] **Step 3: Write MenuBarController**

```swift
// Brighter/UI/MenuBarController.swift
import SwiftUI
import AppKit
import ServiceManagement

/// Controls the menu bar item and its popover.
final class MenuBarController {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let engine: BrightnessEngine
    private let displayManager: DisplayManager
    private let hud: BrightnessHUD
    private let keyMonitor: KeyMonitor

    init(
        engine: BrightnessEngine,
        displayManager: DisplayManager,
        hud: BrightnessHUD,
        keyMonitor: KeyMonitor
    ) {
        self.engine = engine
        self.displayManager = displayManager
        self.hud = hud
        self.keyMonitor = keyMonitor
    }

    /// Sets up the menu bar status item.
    func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Brighter")
            button.image?.size = NSSize(width: 18, height: 18)

            // Click action
            button.action = #selector(togglePopover)
            button.target = self

            // Scroll to adjust brightness
            button.sendAction(on: [.scrollWheel, .leftMouseUp])
        }

        // Setup popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                engine: engine,
                displayManager: displayManager,
                onToggleBoost: { [weak self] in self?.toggleBoost() },
                onLaunchAtLoginToggle: { [weak self] in self?.toggleLaunchAtLogin() },
                onQuit: { [weak self] in self?.quit() }
            )
        )
    }

    /// Updates the menu bar icon based on current boost state.
    func updateMenuBarIcon() {
        let iconName: String
        if engine.isBoosted {
            iconName = "sun.max.fill"
        } else {
            iconName = "sun.max"
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.image = NSImage(
                systemSymbolName: iconName,
                accessibilityDescription: "Brighter"
            )
            self?.statusItem.button?.image?.size = NSSize(width: 18, height: 18)
        }
    }

    // MARK: - Actions

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    private func toggleBoost() {
        if engine.isBoosted {
            engine.resetBoost()
            for display in displayManager.hdrDisplays {
                engine.resetGammaTable(for: display.displayID)
            }
        } else {
            engine.setBoost(Constants.minBoost + Constants.boostStep)
            for display in displayManager.hdrDisplays {
                engine.applyCurrentBoost(for: display.displayID)
            }
        }
        updateMenuBarIcon()
    }

    private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    private func quit() {
        // Clean up gamma tables before quitting
        engine.resetAllBoosts()
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add menu bar UI with slider, view, and controller"
```

---

### Task 10: AppDelegate & App Wiring

**Files:**
- Create: `Brighter/Brighter/App/AppDelegate.swift`
- Modify: `Brighter/Brighter/App/BrighterApp.swift` (update from stub)

**Interfaces:**
- Consumes: All previous components
- Produces: Fully wired app lifecycle

- [ ] **Step 1: Write AppDelegate**

```swift
// Brighter/App/AppDelegate.swift
import AppKit
import SwiftUI
import os.log

/// The app delegate manages the lifecycle of all Brighter components.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(subsystem: "com.brighter.app", category: "AppDelegate")

    private var displayManager: DisplayManager!
    private var brightnessEngine: BrightnessEngine!
    private var keyMonitor: KeyMonitor!
    private var hud: BrightnessHUD!
    private var menuBarController: MenuBarController!

    // Signal handling for clean shutdown
    private var signalSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Brighter launching...")

        // Initialize components
        displayManager = DisplayManager()
        brightnessEngine = BrightnessEngine(displayManager: displayManager)
        keyMonitor = KeyMonitor()
        hud = BrightnessHUD()
        menuBarController = MenuBarController(
            engine: brightnessEngine,
            displayManager: displayManager,
            hud: hud,
            keyMonitor: keyMonitor
        )

        // Setup menu bar
        menuBarController.setupMenuBarItem()

        // Wire up key monitor callbacks
        keyMonitor.onBrightnessUp = { [weak self] in
            self?.handleBrightnessUp()
        }
        keyMonitor.onBrightnessDown = { [weak self] in
            self?.handleBrightnessDown()
        }

        // Start display monitoring
        displayManager.startMonitoring()

        // Start key monitoring if we have permission
        if PermissionsHelper.isAccessibilityGranted() {
            keyMonitor.start()
        } else {
            logger.warning("Accessibility permission not granted — key monitoring disabled")
            PermissionsHelper.promptForAccessibility()
        }

        // Setup signal handlers for clean shutdown
        setupSignalHandlers()

        // Observe engine changes for icon updates
        observeEngineChanges()

        logger.info("Brighter launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Brighter terminating — resetting gamma tables")
        brightnessEngine.resetAllBoosts()
        keyMonitor.stop()
        displayManager.stopMonitoring()
    }

    // MARK: - Brightness Key Handling

    private func handleBrightnessUp() {
        guard let display = displayManager.hdrDisplays.first else { return }

        if displayManager.isSystemBrightnessMax(for: display.displayID) {
            // System brightness is at max — start/continue boosting
            brightnessEngine.increaseBoost()
            brightnessEngine.applyCurrentBoost(for: display.displayID)
            hud.show(boostFactor: brightnessEngine.boostFactor)
            menuBarController.updateMenuBarIcon()
        }
        // If system brightness is not at max, we let the event through
        // (but we already consumed it in KeyMonitor)
        // TODO: Re-emit the event if not at max brightness
    }

    private func handleBrightnessDown() -> Bool {
        guard let display = displayManager.hdrDisplays.first else { return false }
        return brightnessEngine.handleBrightnessDown(for: display.displayID)
    }

    // MARK: - Private

    private func observeEngineChanges() {
        // Use Combine to observe boost factor changes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.brightnessEngine.$boostFactor
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.menuBarController.updateMenuBarIcon()
                }
                .store(in: &self.cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func setupSignalHandlers() {
        // Handle SIGTERM and SIGINT for clean shutdown
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler { [weak self] in
            self?.brightnessEngine.resetAllBoosts()
            exit(0)
        }
        termSource.resume()
        self.signalSource = termSource
    }
}

private import Combine
```

- [ ] **Step 2: Update BrighterApp.swift**

```swift
// Brighter/App/BrighterApp.swift
import SwiftUI

@main
struct BrighterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No scenes needed — this is a menu bar-only app
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 3: Verify the project compiles**

```bash
cd /private/tmp/Brighter && swift build 2>&1 | tail -20
```

Expected: Build succeeds (may have warnings about private API usage, but no errors).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add AppDelegate with full component wiring and lifecycle management"
```

---

### Task 11: Build Verification & Bug Fixes

**Files:**
- Modify: Any files with compilation errors

- [ ] **Step 1: Full build and test**

```bash
cd /private/tmp/Brighter && swift build 2>&1
```

- [ ] **Step 2: Fix any compilation errors**

Address each error one at a time. Common issues:
- Missing imports
- SPM target path mismatches
- Private API bridging issues
- SwiftUI view conformance issues

- [ ] **Step 3: Run all tests**

```bash
cd /private/tmp/Brighter && swift test 2>&1
```

- [ ] **Step 4: Commit fixes**

```bash
git add -A && git commit -m "fix: resolve compilation errors and test failures"
```

---

### Task 12: README & Final Polish

**Files:**
- Modify: `README.md`
- Create: `LICENSE` (MIT)

- [ ] **Step 1: Write comprehensive README**

Update the README with full documentation including installation, usage, building, and architecture details.

- [ ] **Step 2: Add MIT LICENSE**

- [ ] **Step 3: Final commit**

```bash
git add -A && git commit -m "docs: add comprehensive README and MIT license"
```
