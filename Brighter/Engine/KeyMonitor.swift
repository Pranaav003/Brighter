import CoreGraphics
import AppKit
import os.log

/// Monitors brightness key events using a CGEventTap.
///
/// Modern macOS (especially Apple Silicon) sends brightness keys as "system-defined"
/// events (type 14), not regular key-down events. This monitor listens for both.
final class KeyMonitor {

    /// Called when brightness-up is pressed at max system brightness.
    /// Returns whether the event should be consumed (true = we handled it).
    var onBrightnessUp: (() -> Bool)?

    /// Called when brightness-down is pressed while boost may be active.
    /// Returns whether the event should be consumed (true = we handled it).
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

        // Listen for BOTH key-down AND system-defined events.
        // On Apple Silicon Macs, brightness keys come as system-defined events (type 14),
        // not as regular key-down events. Key codes 107/113 may not fire at all.
        let systemDefinedType: UInt32 = 14  // NX_SYSDEFINED
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << UInt64(systemDefinedType))

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
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

        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        logger.info("Key monitor started — listening for brightness keys (systemDefined + keyDown)")
    }

    /// Stops monitoring brightness key events.
    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
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

    /// NX_KEYTYPE constants for brightness keys (HID Consumer page).
    private static let NX_KEYTYPE_BRIGHTNESS_UP: Int64 = 3
    private static let NX_KEYTYPE_BRIGHTNESS_DOWN: Int64 = 2

    /// NX_SUBTYPE for auxiliary control buttons (brightness, volume, etc.).
    private static let NX_SUBTYPE_AUX_CONTROL_BUTTONS: Int64 = 8

    /// Key-down state flag in system-defined event data.
    private static let NX_KEYDOWN: Int64 = 0x0A

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled by timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Method 1: System-defined events (how Apple Silicon Macs send brightness keys)
        // These are NSEvent.systemDefined events (CGEventType raw value 14) that carry
        // the brightness key info in subtype (field 10) and data1 (field 12).
        if type.rawValue == 14 {
            let subtype = event.getIntegerValueField(CGEventField(rawValue: 10)!)

            guard subtype == Self.NX_SUBTYPE_AUX_CONTROL_BUTTONS else {
                return Unmanaged.passUnretained(event)
            }

            let data1 = event.getIntegerValueField(CGEventField(rawValue: 12)!)
            let keyType = (data1 >> 16) & 0xFF
            let keyState = (data1 >> 8) & 0xFF

            // Only respond to key-down, not key-up
            guard keyState == Self.NX_KEYDOWN else {
                return Unmanaged.passUnretained(event)
            }

            if keyType == Self.NX_KEYTYPE_BRIGHTNESS_UP {
                logger.info("Brightness UP (systemDefined, keyType=\(keyType))")
                let shouldConsume = onBrightnessUp?() ?? false
                return shouldConsume ? nil : Unmanaged.passUnretained(event)
            }

            if keyType == Self.NX_KEYTYPE_BRIGHTNESS_DOWN {
                logger.info("Brightness DOWN (systemDefined, keyType=\(keyType))")
                let shouldConsume = onBrightnessDown?() ?? false
                return shouldConsume ? nil : Unmanaged.passUnretained(event)
            }

            return Unmanaged.passUnretained(event)
        }

        // Method 2: Regular key-down events (fallback for some keyboard configs)
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == 107 || keyCode == 145 {
                logger.info("Brightness UP (keyDown, code=\(keyCode))")
                let shouldConsume = onBrightnessUp?() ?? false
                return shouldConsume ? nil : Unmanaged.passUnretained(event)
            }

            if keyCode == 113 || keyCode == 144 {
                logger.info("Brightness DOWN (keyDown, code=\(keyCode))")
                let shouldConsume = onBrightnessDown?() ?? false
                return shouldConsume ? nil : Unmanaged.passUnretained(event)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}