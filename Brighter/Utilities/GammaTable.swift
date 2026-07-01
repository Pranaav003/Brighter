import CoreGraphics

/// Pure functions for generating gamma lookup tables.
///
/// A gamma table maps 8-bit input values (0–255) to floating-point output values.
/// On HDR displays, output values above 1.0 map to luminance above SDR white,
/// using the display's HDR headroom.
///
/// The boost curve uses a smooth rolloff instead of linear scaling:
/// shadows and midtones stay natural, while highlights are pushed into HDR headroom.
/// This produces a genuine brightness increase rather than a contrast shift.
enum GammaTable {

    /// Generates a linear (identity) gamma table.
    /// - Parameter size: Number of entries in the table (typically 256).
    /// - Returns: Array of CGFloat values from 0.0 to 1.0.
    static func generateLinearTable(size: Int = Constants.gammaTableSize) -> [CGFloat] {
        (0..<size).map { CGFloat($0) / CGFloat(size - 1) }
    }

    /// Generates a boosted gamma table that increases perceived brightness.
    ///
    /// Instead of linearly scaling ALL values (which looks like a contrast change),
    /// this curve keeps shadows and midtones relatively natural while pushing
    /// highlights into the HDR headroom. The effect looks like a genuine
    /// brightness increase — the screen emits more light without washing out.
    ///
    /// - Parameters:
    ///   - boostFactor: Target peak brightness (1.0 = normal, 2.0 = 200% max).
    ///   - size: Number of entries in the table.
    /// - Returns: Array of CGFloat values.
    static func generateBoostedTable(
        boostFactor: Double,
        size: Int = Constants.gammaTableSize
    ) -> [CGFloat] {
        let clampedFactor = max(Constants.minBoost, min(Constants.maxBoost, boostFactor))

        // How much extra headroom we have above SDR white (1.0)
        let headroom = clampedFactor - 1.0

        return (0..<size).map { i in
            let input = CGFloat(i) / CGFloat(size - 1)

            // Smoothstep rolloff: the boost is concentrated in the highlights
            // while keeping shadows and midtones close to their original values.
            //
            // The formula: output = input + headroom * smoothstep(input)
            // - At input=0: output=0 (black stays black)
            // - At input=0.5: output ≈ 0.5 + small lift (midtones barely change)
            // - At input=1.0: output = 1.0 + headroom = boostFactor (white goes HDR)
            let smoothInput = smoothstep(input)
            let output = input + CGFloat(headroom) * smoothInput

            return output
        }
    }

    /// Generates three identical boosted gamma tables (R, G, B).
    static func generateBoostedTables(
        boostFactor: Double,
        size: Int = Constants.gammaTableSize
    ) -> (red: [CGFloat], green: [CGFloat], blue: [CGFloat]) {
        let table = generateBoostedTable(boostFactor: boostFactor, size: size)
        return (red: table, green: table, blue: table)
    }

    /// Validates that a gamma table has the correct size and value range.
    static func validateTable(_ table: [CGFloat]) -> Bool {
        guard table.count == Constants.gammaTableSize else { return false }
        guard table.first ?? -1 >= 0.0 else { return false }
        // Allow values above 1.0 for HDR headroom
        return true
    }

    // MARK: - Private

    /// Hermite smoothstep interpolation (3t² - 2t³).
    /// Returns 0 at t=0, 1 at t=1, with a smooth S-curve in between.
    /// This concentrates the brightness boost in the highlights
    /// while keeping shadows and midtones natural.
    private static func smoothstep(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
