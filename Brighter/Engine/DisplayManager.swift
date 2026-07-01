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
        if result == .success {
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
        // Strategy: Check NSScreen EDR value
        // This is the most reliable method on macOS 13+
        if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            if screen.maximumPotentialEDRValue > 1.0 {
                return true
            }
        }

        // Strategy: Check IOKit properties for HDR/EDR support
        let registryID = CGDisplayUnitNumber(displayID)
        let servicePort = IOKitGetMatchingService(
            kIOMasterPortDefault,
            IORegistryEntryIDMatching(registryID)
        )
        defer { IOObjectRelease(servicePort) }

        if servicePort != 0 {
            if let edrProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "SupportsHDR" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let supportsHDR = edrProperty.takeUnretainedValue() as? Bool, supportsHDR {
                    return true
                }
            }

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

        return false
    }

    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
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
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let screenNumber = deviceDescription[key] as? NSNumber {
            return screenNumber.uint32Value
        }
        return 0
    }
}
