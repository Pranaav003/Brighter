import Foundation

enum Constants {
    /// Maximum boost factor (5.0x = 500% of SDR white, well beyond typical HDR headroom)
    static let maxBoost: Double = 5.0

    /// Minimum boost factor (1.0 = normal, no boost)
    static let minBoost: Double = 1.0

    /// Step size per brightness key press (gives ~40 steps from 1.0 to 5.0)
    static let boostStep: Double = 0.10

    /// How long the HUD overlay stays visible (seconds)
    static let hudDisplayDuration: Double = 1.5

    /// How often to poll system brightness (seconds)
    static let brightnessPollInterval: Double = 0.5

    /// Number of entries in a gamma table
    static let gammaTableSize: Int = 256

    /// Number of brightness bars in the macOS OSD
    static let systemBrightnessBars: Int = 16

    /// Number of additional boost bars shown in the HUD
    static let boostBars: Int = 40

    /// UserDefaults keys
    enum Defaults {
        static let boostEnabled = "boostEnabled"
        static let boostFactor = "boostFactor"
        static let launchAtLogin = "launchAtLogin"
        static let maxBoost = "maxBoost"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}
