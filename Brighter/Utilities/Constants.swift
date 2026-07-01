import Foundation

enum Constants {
    /// Maximum boost factor (2.5x = 250% of SDR white, matching MacBook Pro XDR headroom)
    static let maxBoost: Double = 2.5

    /// Minimum boost factor (1.0 = normal, no boost)
    static let minBoost: Double = 1.0

    /// Step size per brightness key press (gives ~25 steps from 1.0 to 2.5)
    static let boostStep: Double = 0.06

    /// How long the HUD overlay stays visible (seconds)
    static let hudDisplayDuration: Double = 1.5

    /// How often to poll system brightness (seconds)
    static let brightnessPollInterval: Double = 0.5

    /// Number of entries in a gamma table
    static let gammaTableSize: Int = 256

    /// Number of brightness bars in the macOS OSD
    static let systemBrightnessBars: Int = 16

    /// Number of additional boost bars shown in the HUD
    static let boostBars: Int = 25

    /// UserDefaults keys
    enum Defaults {
        static let boostEnabled = "boostEnabled"
        static let boostFactor = "boostFactor"
        static let launchAtLogin = "launchAtLogin"
        static let maxBoost = "maxBoost"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}
