import AppKit
import Combine
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Components

    private let displayManager = DisplayManager()
    private lazy var engine = BrightnessEngine(displayManager: displayManager)
    private lazy var hud = BrightnessHUD()
    private lazy var keyMonitor = KeyMonitor()
    private lazy var menuBarController = MenuBarController(
        engine: engine,
        displayManager: displayManager,
        hud: hud,
        keyMonitor: keyMonitor
    )

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — we're a menu bar app
        NSApp.setActivationPolicy(.accessory)

        // 1. Setup the menu bar
        menuBarController.setupMenuBarItem()

        // 2. Wire up KeyMonitor callbacks
        keyMonitor.onBrightnessUp = { [weak self] in
            self?.handleBrightnessUp() ?? false
        }

        keyMonitor.onBrightnessDown = { [weak self] in
            self?.handleBrightnessDown() ?? false
        }

        // 3. Observe boost factor changes to update menu bar icon
        engine.$boostFactor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        // 4. Start display monitoring
        displayManager.startMonitoring()

        // 5. Start key monitoring if Accessibility permission is granted
        if PermissionsHelper.isAccessibilityGranted() {
            keyMonitor.start()
        } else {
            logger.warning("Accessibility not granted — prompting")
            PermissionsHelper.promptForAccessibility()
            // Retry after a delay to give the user time to grant permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if PermissionsHelper.isAccessibilityGranted() {
                    self?.keyMonitor.start()
                    self?.logger.info("Key monitor started after permission grant")
                }
            }
        }

        // 6. Setup signal handler for clean shutdown (SIGTERM)
        setupSignalHandlers()

        logger.info("Brighter launched — \(self.displayManager.allDisplays.count) displays, HDR: \(self.displayManager.hasHDRDisplay)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.resetAllBoosts()
        keyMonitor.stop()
        displayManager.stopMonitoring()
        logger.info("Brighter terminated")
    }

    // MARK: - Brightness Key Handlers

    /// Handles brightness-up key press.
    /// Returns true if the event was consumed (boost was applied), false to pass through to macOS.
    private func handleBrightnessUp() -> Bool {
        // Use boostableDisplays (all displays) instead of just HDR-detected ones.
        // The gamma table will either work on HDR displays or clip harmlessly on SDR.
        var didBoost = false
        for display in displayManager.boostableDisplays {
            if displayManager.isSystemBrightnessMax(for: display.displayID) {
                engine.increaseBoost()
                engine.applyCurrentBoost(for: display.displayID)
                didBoost = true
            }
        }

        if didBoost {
            hud.show(boostFactor: engine.boostFactor)
            logger.info("Boosted to \(self.engine.boostFactor, format: .fixed(precision: 2))")
            return true
        }

        return false
    }

    /// Handles brightness-down key press.
    /// Returns true if the event was consumed (boost was decreased), false to pass through.
    private func handleBrightnessDown() -> Bool {
        var anyConsumed = false

        for display in displayManager.boostableDisplays {
            let consumed = engine.handleBrightnessDown(for: display.displayID)
            if consumed {
                anyConsumed = true
            }
        }

        if anyConsumed {
            if engine.isBoosted {
                hud.show(boostFactor: engine.boostFactor)
            } else {
                hud.hide()
            }
        }

        return anyConsumed
    }

    // MARK: - Signal Handlers

    private let logger = Logger(subsystem: "com.brighter.app", category: "AppDelegate")

    private func setupSignalHandlers() {
        var sigtermAction = sigaction()
        sigemptyset(&sigtermAction.sa_mask)
        sigtermAction.__sigaction_u.__sa_handler = { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .brighterSigTermReceived, object: nil)
            }
        }
        sigtermAction.sa_flags = 0
        sigaction(SIGTERM, &sigtermAction, nil)

        NotificationCenter.default.addObserver(
            forName: .brighterSigTermReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine.resetAllBoosts()
            exit(0)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let brighterSigTermReceived = Notification.Name("brighterSigTermReceived")
}
