import SwiftUI
import AppKit
import os

/// A custom HUD overlay that shows the boosted brightness level,
/// similar to the macOS volume/brightness OSD.
final class BrightnessHUD {

    private var hudWindow: NSWindow?
    private var hideTimer: Timer?
    private let logger = os.Logger(subsystem: "com.brighter.app", category: "BrightnessHUD")

    /// Shows the HUD with the current boost factor.
    func show(boostFactor: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.showOnMainThread(boostFactor: boostFactor)
        }
    }

    /// Hides the HUD immediately.
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideOnMainThread()
        }
    }

    // MARK: - Private

    private func showOnMainThread(boostFactor: Double) {
        hideTimer?.invalidate()

        let boostLevel = Int(round((boostFactor - Constants.minBoost) / Constants.boostStep))

        let view = HUDView(
            systemBars: Constants.systemBrightnessBars,
            boostBars: Constants.boostBars,
            filledBoostBars: boostLevel
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 120)

        if hudWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 120),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .screenSaver + 1
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            hudWindow = window
        }

        hudWindow?.contentView = hostingView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 280
            let windowHeight: CGFloat = 120
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.maxY - windowHeight - 20
            hudWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hudWindow?.orderFrontRegardless()

        hideTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.hudDisplayDuration,
            repeats: false
        ) { [weak self] _ in
            self?.hideOnMainThread()
        }
    }

    private func hideOnMainThread() {
        hudWindow?.orderOut(nil)
    }
}

// MARK: - SwiftUI HUD View

private struct HUDView: View {
    let systemBars: Int
    let boostBars: Int
    let filledBoostBars: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                HStack(spacing: 3) {
                    ForEach(0..<systemBars, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 6, height: 14)
                    }

                    ForEach(0..<boostBars, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(index < filledBoostBars
                                  ? Color.amber
                                  : Color.white.opacity(0.2))
                            .frame(width: 6, height: 14)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Color Extension

private extension Color {
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.03)
}
