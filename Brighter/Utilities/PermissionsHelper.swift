import ApplicationServices
import AppKit

/// Helper for checking and requesting Accessibility permissions.
enum PermissionsHelper {

    /// Whether the app currently has Accessibility permission.
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    /// Prompts the user to grant Accessibility permission.
    /// Opens System Settings and shows a prompt dialog.
    static func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility section of System Settings.
    static func openAccessibilitySettings() {
        // macOS 13+ uses the new Settings URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}