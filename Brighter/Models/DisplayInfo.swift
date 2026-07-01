import CoreGraphics

/// Represents a connected display and its capabilities.
struct DisplayInfo: Equatable, Identifiable {
    /// The CoreGraphics display identifier.
    let displayID: CGDirectDisplayID

    /// Whether this display supports HDR luminance above SDR white.
    let isHDR: Bool

    /// Human-readable display name.
    let name: String

    /// Peak luminance in nits, if known.
    let peakLuminance: Double?

    var id: CGDirectDisplayID { displayID }
}
