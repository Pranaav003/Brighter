import CoreGraphics

/// Pure functions for generating gamma lookup tables.
///
/// A gamma table maps 8-bit input values (0–255) to floating-point output values.
/// On HDR displays, output values above 1.0 map to luminance above SDR white,
/// using the display's HDR headroom.
enum GammaTable {

    /// Generates a linear (identity) gamma table.
    /// - Parameter size: Number of entries in the table (typically 256).
    /// - Returns: Array of CGFloat values from 0.0 to 1.0.
    static func generateLinearTable(size: Int = Constants.gammaTableSize) -> [CGFloat] {
        (0..<size).map { CGFloat($0) / CGFloat(size - 1) }
    }

    /// Generates a boosted gamma table that scales output by a boost factor.
    /// - Parameters:
    ///   - boostFactor: Multiplier applied to output values (1.0 = normal, 1.6 = max boost).
    ///   - size: Number of entries in the table.
    /// - Returns: Array of CGFloat values from 0.0 to boostFactor.
    static func generateBoostedTable(
        boostFactor: Double,
        size: Int = Constants.gammaTableSize
    ) -> [CGFloat] {
        let clampedFactor = max(Constants.minBoost, min(Constants.maxBoost, boostFactor))
        return (0..<size).map { i in
            CGFloat(Double(i) / Double(size - 1) * clampedFactor)
        }
    }

    /// Generates three identical boosted gamma tables (R, G, B).
    /// - Parameters:
    ///   - boostFactor: Multiplier applied to output values.
    ///   - size: Number of entries per table.
    /// - Returns: Tuple of (red, green, blue) gamma tables.
    static func generateBoostedTables(
        boostFactor: Double,
        size: Int = Constants.gammaTableSize
    ) -> (red: [CGFloat], green: [CGFloat], blue: [CGFloat]) {
        let table = generateBoostedTable(boostFactor: boostFactor, size: size)
        return (red: table, green: table, blue: table)
    }

    /// Validates that a gamma table has the correct size and value range.
    /// - Parameter table: The gamma table to validate.
    /// - Returns: True if the table is valid.
    static func validateTable(_ table: [CGFloat]) -> Bool {
        guard table.count == Constants.gammaTableSize else { return false }
        guard table.first ?? -1 >= 0.0 else { return false }
        // Allow values above 1.0 for HDR headroom
        return true
    }
}
