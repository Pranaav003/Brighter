import AppKit
import Metal
import QuartzCore
import Combine
import os.log

/// The core engine that manages brightness boost using a Metal EDR overlay.
///
/// Instead of gamma table manipulation, this uses a fullscreen CAMetalLayer with
/// `wantsExtendedDynamicRangeContent = true` to activate the display's HDR mode.
/// A semi-transparent overlay with HDR pixel values physically drives the display
/// to emit more light — the same mechanism used for HDR video content.
final class BrightnessEngine: ObservableObject {

    /// Current boost factor (1.0 = no boost, up to 2.0 = 200%).
    @Published private(set) var boostFactor: Double = Constants.minBoost

    /// Whether boost is currently active.
    var isBoosted: Bool {
        boostFactor > Constants.minBoost
    }

    private let displayManager: DisplayManager
    private let logger = Logger(subsystem: "com.brighter.app", category: "BrightnessEngine")

    // Metal EDR overlay
    private var overlayWindow: NSWindow?
    private var metalLayer: CAMetalLayer?
    private var metalDevice: MTLDevice?
    private var renderTimer: Timer?

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
        self.metalDevice = MTLCreateSystemDefaultDevice()
    }

    // MARK: - Boost Control

    func increaseBoost() {
        let newFactor = min(boostFactor + Constants.boostStep, Constants.maxBoost)
        setBoost(newFactor)
    }

    func decreaseBoost() {
        let newFactor = max(boostFactor - Constants.boostStep, Constants.minBoost)
        setBoost(newFactor)
    }

    func setBoost(_ factor: Double) {
        let clamped = max(Constants.minBoost, min(Constants.maxBoost, factor))
        boostFactor = clamped
        logger.info("Boost factor set to \(clamped, format: .fixed(precision: 2))")

        if clamped > Constants.minBoost {
            showOverlay()
            renderFrame()
        } else {
            hideOverlay()
        }
    }

    func resetBoost() {
        setBoost(Constants.minBoost)
    }

    func resetAllBoosts() {
        hideOverlay()
        boostFactor = Constants.minBoost
    }

    // MARK: - Gamma Table Stubs (for compatibility with existing code)

    func applyCurrentBoost(for displayID: CGDirectDisplayID) {
        if isBoosted {
            showOverlay()
            renderFrame()
        }
    }

    func resetGammaTable(for displayID: CGDirectDisplayID) {
        hideOverlay()
    }

    func handleBrightnessUp(for displayID: CGDirectDisplayID) {
        increaseBoost()
    }

    func handleBrightnessDown(for displayID: CGDirectDisplayID) -> Bool {
        if isBoosted {
            decreaseBoost()
            return isBoosted
        }
        return false
    }

    // MARK: - Metal EDR Overlay

    private func showOverlay() {
        guard overlayWindow == nil else { return }
        guard let device = metalDevice else {
            logger.error("No Metal device available")
            return
        }
        guard let screen = NSScreen.main else { return }

        // Create fullscreen borderless window
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.animationBehavior = .none

        // Create Metal layer with EDR support
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        layer.frame = window.contentView!.bounds
        layer.isOpaque = false
        layer.contentsScale = screen.backingScaleFactor

        window.contentView?.wantsLayer = true
        window.contentView?.layer = layer
        window.orderFrontRegardless()

        self.overlayWindow = window
        self.metalLayer = layer

        // Render at display refresh rate to keep EDR active
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.renderFrame()
        }

        logger.info("EDR overlay shown")
    }

    private func hideOverlay() {
        renderTimer?.invalidate()
        renderTimer = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        metalLayer = nil
        logger.info("EDR overlay hidden")
    }

    private func renderFrame() {
        guard let layer = metalLayer,
              let device = metalDevice,
              let drawable = layer.nextDrawable(),
              let queue = device.makeCommandQueue(),
              let buffer = queue.makeCommandBuffer() else { return }

        // Calculate overlay parameters based on boost factor.
        // Uses extreme HDR brightness with minimal alpha (combo E style).
        // Starts at 0 alpha and gradually ramps to avoid sudden white veil.

        let intensity = boostFactor - 1.0  // 0.0 to 1.0
        let brightness = 20.0              // Constant high HDR value
        let alpha = intensity * 0.03       // 0.0 to 0.03 (gradual ramp from nothing)

        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = drawable.texture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].clearColor = MTLClearColor(
            red: brightness,
            green: brightness,
            blue: brightness,
            alpha: alpha
        )
        desc.colorAttachments[0].storeAction = .store

        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}
