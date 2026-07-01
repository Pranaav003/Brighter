import CoreGraphics
import Combine
import os.log

/// The core engine that manages brightness boost state and applies gamma tables.
final class BrightnessEngine: ObservableObject {

    /// Current boost factor (1.0 = no boost, up to 1.6).
    @Published private(set) var boostFactor: Double = Constants.minBoost

    /// Whether boost is currently active.
    var isBoosted: Bool {
        boostFactor > Constants.minBoost
    }

    /// The display manager for detecting displays and reading system brightness.
    private let displayManager: DisplayManager

    /// Logger for this engine.
    private let logger = Logger(subsystem: "com.brighter.app", category: "BrightnessEngine")

    /// Per-display boost storage.
    private var perDisplayBoost: [CGDirectDisplayID: Double] = [:]

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    // MARK: - Boost Control

    /// Increases the boost factor by one step.
    func increaseBoost() {
        let newFactor = min(boostFactor + Constants.boostStep, Constants.maxBoost)
        setBoost(newFactor)
    }

    /// Decreases the boost factor by one step.
    func decreaseBoost() {
        let newFactor = max(boostFactor - Constants.boostStep, Constants.minBoost)
        setBoost(newFactor)
    }

    /// Sets the boost factor to a specific value.
    func setBoost(_ factor: Double) {
        let clamped = max(Constants.minBoost, min(Constants.maxBoost, factor))
        boostFactor = clamped
        logger.info("Boost factor set to \(clamped, format: .fixed(precision: 2))")
    }

    /// Resets boost to 1.0.
    func resetBoost() {
        setBoost(Constants.minBoost)
    }

    // MARK: - Gamma Table Application

    /// Applies the current boost to a specific display via gamma table.
    func applyCurrentBoost(for displayID: CGDirectDisplayID) {
        let (red, green, blue) = GammaTable.generateBoostedTables(boostFactor: boostFactor)

        guard GammaTable.validateTable(red),
              GammaTable.validateTable(green),
              GammaTable.validateTable(blue) else {
            logger.error("Invalid gamma table generated for boost factor \(self.boostFactor)")
            return
        }

        let redFloat = red.map { Float($0) }
        let greenFloat = green.map { Float($0) }
        let blueFloat = blue.map { Float($0) }

        let result = redFloat.withUnsafeBufferPointer { redBuf in
            greenFloat.withUnsafeBufferPointer { greenBuf in
                blueFloat.withUnsafeBufferPointer { blueBuf in
                    CGSetDisplayTransferByTable(
                        displayID,
                        UInt32(redFloat.count),
                        redBuf.baseAddress!,
                        greenBuf.baseAddress!,
                        blueBuf.baseAddress!
                    )
                }
            }
        }

        if result != .success {
            logger.error("Failed to set gamma table for display \(displayID): \(result.rawValue)")
        } else {
            perDisplayBoost[displayID] = boostFactor
            logger.info("Applied boost \(self.boostFactor, format: .fixed(precision: 2)) to display \(displayID)")
        }
    }

    /// Resets the gamma table for a specific display to its default (linear) state.
    func resetGammaTable(for displayID: CGDirectDisplayID) {
        let red = GammaTable.generateLinearTable()
        let green = GammaTable.generateLinearTable()
        let blue = GammaTable.generateLinearTable()

        let redFloat = red.map { Float($0) }
        let greenFloat = green.map { Float($0) }
        let blueFloat = blue.map { Float($0) }

        let result = redFloat.withUnsafeBufferPointer { redBuf in
            greenFloat.withUnsafeBufferPointer { greenBuf in
                blueFloat.withUnsafeBufferPointer { blueBuf in
                    CGSetDisplayTransferByTable(
                        displayID,
                        UInt32(redFloat.count),
                        redBuf.baseAddress!,
                        greenBuf.baseAddress!,
                        blueBuf.baseAddress!
                    )
                }
            }
        }

        if result != .success {
            logger.error("Failed to reset gamma table for display \(displayID): \(result.rawValue)")
        } else {
            perDisplayBoost.removeValue(forKey: displayID)
            logger.info("Reset gamma table for display \(displayID)")
        }
    }

    /// Resets all gamma tables for all displays that have been boosted.
    func resetAllBoosts() {
        for displayID in perDisplayBoost.keys {
            resetGammaTable(for: displayID)
        }
        resetBoost()
    }

    /// Handles a brightness-up key event at maximum system brightness.
    func handleBrightnessUp(for displayID: CGDirectDisplayID) {
        guard displayManager.isSystemBrightnessMax(for: displayID) else {
            return
        }
        increaseBoost()
        applyCurrentBoost(for: displayID)
    }

    /// Handles a brightness-down key event when boost may be active.
    /// Returns whether the event should be consumed (true) or passed to the system (false).
    func handleBrightnessDown(for displayID: CGDirectDisplayID) -> Bool {
        if isBoosted {
            decreaseBoost()
            if isBoosted {
                applyCurrentBoost(for: displayID)
                return true
            } else {
                resetGammaTable(for: displayID)
                return false
            }
        }
        return false
    }
}
