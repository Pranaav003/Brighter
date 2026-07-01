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
        NSApp.setActivationPolicy(.accessory)

        menuBarController.setupMenuBarItem()

        engine.$boostFactor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        displayManager.startMonitoring()
        setupSignalHandlers()

        logger.info("Brighter launched — \(self.displayManager.allDisplays.count) displays, HDR: \(self.displayManager.hasHDRDisplay)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.resetAllBoosts()
        displayManager.stopMonitoring()
        logger.info("Brighter terminated")
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

extension Notification.Name {
    static let brighterSigTermReceived = Notification.Name("brighterSigTermReceived")
}
