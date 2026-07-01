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
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.scrollWheel, .leftMouseUp])
        }

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
        let iconName = engine.isBoosted ? "sun.max.fill" : "sun.max"

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
            for display in displayManager.boostableDisplays {
                engine.resetGammaTable(for: display.displayID)
            }
        } else {
            engine.setBoost(Constants.minBoost + Constants.boostStep)
            for display in displayManager.boostableDisplays {
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
        engine.resetAllBoosts()
        NSApplication.shared.terminate(nil)
    }
}
