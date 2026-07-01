import Foundation

/// Represents the combined system brightness and boost state.
struct BrightnessState: Equatable {
    /// System brightness level (0.0–1.0).
    let systemBrightness: Double

    /// Boost factor applied via gamma table (1.0–1.6).
    let boostFactor: Double

    /// Whether boost is currently active (boostFactor > 1.0).
    var isBoosted: Bool {
        boostFactor > Constants.minBoost
    }

    /// The effective brightness including boost.
    var effectiveBrightness: Double {
        systemBrightness * boostFactor
    }

    init(systemBrightness: Double, boostFactor: Double) {
        self.systemBrightness = max(0.0, min(1.0, systemBrightness))
        self.boostFactor = max(Constants.minBoost, min(Constants.maxBoost, boostFactor))
    }

    /// Returns a new state with the boost factor incremented by one step.
    func incrementBoost() -> BrightnessState {
        let newBoost = min(boostFactor + Constants.boostStep, Constants.maxBoost)
        return BrightnessState(systemBrightness: systemBrightness, boostFactor: newBoost)
    }

    /// Returns a new state with the boost factor decremented by one step.
    func decrementBoost() -> BrightnessState {
        let newBoost = max(boostFactor - Constants.boostStep, Constants.minBoost)
        return BrightnessState(systemBrightness: systemBrightness, boostFactor: newBoost)
    }

    /// Returns a new state with boost reset to 1.0.
    func resetBoost() -> BrightnessState {
        BrightnessState(systemBrightness: systemBrightness, boostFactor: Constants.minBoost)
    }

    /// Returns a new state with a specific boost factor.
    func withBoost(_ factor: Double) -> BrightnessState {
        BrightnessState(systemBrightness: systemBrightness, boostFactor: factor)
    }
}
