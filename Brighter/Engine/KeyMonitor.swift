import CoreGraphics
import AppKit
import os.log

/// Monitors brightness key events using a CGEventTap.
///
/// Intercepts brightness-up key presses ONLY when the system brightness is already at max
/// (so we can "keep going higher"). Intercepts brightness-down ONLY when boost is active
/// (to step down through boost levels first). All other key events pass through untouched.
final class KeyMonitor {

    /// Called when brightness-up is pressed at max system brightness.
    /// Returns whether the event should be consumed (true = we handled it, false = pass through).
    var onBrightnessUp: (() -> Bool)?

    /// Called when brightness-down is pressed while boost may be active.
    /// Returns whether the event should be consumed (true = we handled it, false = pass through).
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

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

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
        logger.info("Key monitor started")
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

    /// Brightness key codes from the HID Usage Tables (Consumer page).
    private static let brightnessUpKeyCode: CGKeyCode = 107
    private static let brightnessDownKeyCode: CGKeyCode = 113

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

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == Self.brightnessUpKeyCode {
            // Ask the engine: should we consume this brightness-up event?
            // (Only consumed when system brightness is at max and we're boosting)
            let shouldConsume = onBrightnessUp?() ?? false
            if shouldConsume {
                logger.debug("Brightness up consumed (boost active)")
                return nil // Consume the event
            }
            // Not at max — let macOS handle it normally
            return Unmanaged.passUnretained(event)
        }

        if keyCode == Self.brightnessDownKeyCode {
            // Ask the engine: should we consume this brightness-down event?
            // (Only consumed when boost is active, to step down through boost levels first)
            let shouldConsume = onBrightnessDown?() ?? false
            if shouldConsume {
                logger.debug("Brightness down consumed (stepping down boost)")
                return nil
            }
            // No boost active — let macOS handle it normally
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }
}
