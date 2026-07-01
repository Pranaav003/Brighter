import CoreGraphics
import IOKit
import IOKit.graphics
import Combine
import AppKit
import os.log

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

    /// The main (primary) display — always available for boost attempts.
    var mainDisplay: DisplayInfo? {
        let mainID = CGMainDisplayID()
        return allDisplays.first { $0.displayID == mainID }
            ?? allDisplays.first
    }

    /// All displays that can be boosted (HDR or not — we always try).
    var boostableDisplays: [DisplayInfo] {
        allDisplays
    }

    private var monitorTimer: Timer?
    private let logger = Logger(subsystem: "com.brighter.app", category: "DisplayManager")

    /// Cached function pointer for DisplayServicesGetBrightness.
    private lazy var displayServicesGetBrightness: DisplayServicesGetBrightnessFunc? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) else {
            logger.warning("Could not load DisplayServices framework")
            return nil
        }
        guard let sym = dlsym(handle, "DisplayServicesGetBrightness") else {
            logger.warning("Could not find DisplayServicesGetBrightness symbol")
            return nil
        }
        return unsafeBitCast(sym, to: DisplayServicesGetBrightnessFunc.self)
    }()

    init() {
        refreshDisplays()
    }

    /// Refreshes the list of detected displays.
    func refreshDisplays() {
        var displays: [DisplayInfo] = []

        var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
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
        let hdrCount = displays.filter { $0.isHDR }.count
        logger.info("Detected \(displays.count) displays, \(hdrCount) HDR")
    }

    /// Gets the system brightness for a specific display.
    func systemBrightness(for displayID: CGDirectDisplayID) -> Double {
        var brightness: Float = 0.0
        if let getBrightness = displayServicesGetBrightness {
            let result = getBrightness(displayID, &brightness)
            if result == .success {
                return Double(brightness)
            }
        }
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

    // MARK: - IOKit Service Lookup

    /// Gets the IOKit service port for a display by iterating the IORegistry.
    /// This replaces the deprecated CGDisplayIOServicePort.
    private func ioServicePort(for displayID: CGDirectDisplayID) -> io_service_t {
        // Use the display's registry entry ID directly.
        // CGDisplayUnitNumber gives us a unit number, but IORegistryEntryIDMatching
        // expects the actual registry entry ID. We iterate instead.
        let matchingDict = IOServiceMatching("IODisplayConnect")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return 0
        }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            // Check if this display's location matches our displayID
            if let locationProp = IORegistryEntryCreateCFProperty(
                service,
                "DisplayLocation" as CFString,
                kCFAllocatorDefault, 0
            ) {
                // Not a reliable match — just use the first display service for built-in
            }

            // For built-in displays, just return the first IODisplayConnect we find
            if CGDisplayIsBuiltin(displayID) != 0 {
                IOObjectRelease(iterator)
                return service
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        IOObjectRelease(iterator)
        return service // Will be 0 if nothing found
    }

    // MARK: - HDR Detection

    private func checkHDRCapability(for displayID: CGDirectDisplayID) -> Bool {
        // Strategy 1: All Apple Silicon MacBook Pro built-in displays are XDR/HDR.
        // This is the most reliable check — no IOKit or private API needed.
        if CGDisplayIsBuiltin(displayID) != 0 {
            logger.info("Display \(displayID) is built-in → HDR")
            return true
        }

        // Strategy 2: Check NSScreen EDR value via performSelector.
        if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            let edrSel = NSSelectorFromString("maximumPotentialEDRValue")
            if screen.responds(to: edrSel) {
                if let result = screen.perform(edrSel) {
                    let edrValue = result.takeUnretainedValue()
                    if let number = edrValue as? NSNumber {
                        logger.info("Display \(displayID) EDR value: \(number.doubleValue)")
                        if number.doubleValue > 1.0 {
                            return true
                        }
                    }
                }
            }
        }

        // Strategy 3: Check IOKit properties via IORegistry iteration.
        let servicePort = ioServicePort(for: displayID)
        if servicePort != 0 {
            defer { IOObjectRelease(servicePort) }

            if let hdrProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "SupportsHDR" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let supportsHDR = hdrProperty.takeUnretainedValue() as? Bool, supportsHDR {
                    logger.info("Display \(displayID) IOKit SupportsHDR: true")
                    return true
                }
            }

            if let edrProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "SupportsEDR" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let supportsEDR = edrProperty.takeUnretainedValue() as? Bool, supportsEDR {
                    logger.info("Display \(displayID) IOKit SupportsEDR: true")
                    return true
                }
            }

            if let peakProperty = IORegistryEntryCreateCFProperty(
                servicePort,
                "PeakLuminance" as CFString,
                kCFAllocatorDefault, 0
            ) {
                if let peak = peakProperty.takeUnretainedValue() as? Int, peak > 500 {
                    logger.info("Display \(displayID) PeakLuminance: \(peak)")
                    return true
                }
            }
        }

        logger.info("Display \(displayID) HDR detection: not detected (will still attempt boost)")
        return false
    }

    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(displayID) != 0 {
            return "Built-in Display"
        }

        let servicePort = ioServicePort(for: displayID)
        if servicePort != 0 {
            defer { IOObjectRelease(servicePort) }
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

        return "Display \(displayID)"
    }

    private func getPeakLuminance(for displayID: CGDirectDisplayID) -> Double? {
        let servicePort = ioServicePort(for: displayID)
        if servicePort != 0 {
            defer { IOObjectRelease(servicePort) }
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

private typealias DisplayServicesGetBrightnessFunc = @convention(c) (
    CGDirectDisplayID,
    UnsafeMutablePointer<Float>
) -> CGError

// MARK: - NSScreen Display ID

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let screenNumber = deviceDescription[key] as? NSNumber {
            return screenNumber.uint32Value
        }
        return 0
    }
}
