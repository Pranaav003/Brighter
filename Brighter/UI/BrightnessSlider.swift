import SwiftUI

/// A custom slider that shows the brightness range from 100% to 250%.
struct BrightnessSlider: View {
    @Binding var boostFactor: Double
    let onBoostChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: $boostFactor,
                in: Constants.minBoost...Constants.maxBoost,
                step: Constants.boostStep
            ) {
                Text("Brightness")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } onEditingChanged: { _ in
                onBoostChange(boostFactor)
            }
            .tint(boostFactor > 1.0 ? .amber : .blue)

            HStack {
                Text("100%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(boostFactor * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(boostFactor > 1.0 ? .amber : .primary)
            }
        }
    }
}

private extension Color {
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.03)
}
