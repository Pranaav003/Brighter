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

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
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
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == Self.brightnessUpKeyCode {
            logger.debug("Brightness up key detected")
            onBrightnessUp?()
            return nil // Consume the event
        }

        if keyCode == Self.brightnessDownKeyCode {
            logger.debug("Brightness down key detected")
            let shouldConsume = onBrightnessDown?() ?? false
            if shouldConsume {
                return nil // Consume the event
            }
            return Unmanaged.passRetained(event)
        }

        return Unmanaged.passRetained(event)
    }
}