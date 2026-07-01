import CoreGraphics
import AppKit
import os.log

/// Minimal key monitor — no brightness key interception needed.
/// Boost is controlled entirely via the menu bar slider.
final class KeyMonitor {

    var onBrightnessUp: (() -> Bool)?
    var onBrightnessDown: (() -> Bool)?
    var onBrightnessDimmedWhileBoosted: (() -> Void)?
    var displayManager: DisplayManager?

    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}
