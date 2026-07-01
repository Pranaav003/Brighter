import SwiftUI

/// The main content view for the menu bar dropdown.
struct MenuBarView: View {
    @ObservedObject var engine: BrightnessEngine
    @ObservedObject var displayManager: DisplayManager
    let onToggleBoost: () -> Void
    let onLaunchAtLoginToggle: () -> Void
    let onQuit: () -> Void

    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !displayManager.hasHDRDisplay {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No HDR display detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if displayManager.hasHDRDisplay {
                BrightnessSlider(
                    boostFactor: Binding(
                        get: { engine.boostFactor },
                        set: { engine.setBoost($0) }
                    ),
                    onBoostChange: { factor in
                        engine.setBoost(factor)
                        if let display = displayManager.boostableDisplays.first {
                            engine.applyCurrentBoost(for: display.displayID)
                        }
                    }
                )

                Toggle("Enable Boost", isOn: Binding(
                    get: { engine.isBoosted },
                    set: { _ in onToggleBoost() }
                ))
                .toggleStyle(.switch)
                .font(.callout)
            }

            Divider()

            Toggle("Start at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .font(.callout)
                .onChange(of: launchAtLogin) { _ in
                    onLaunchAtLoginToggle()
                }

            Divider()

            HStack {
                Button("About Brighter") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Brighter",
                            NSApplication.AboutPanelOptionKey.version: "1.0.0"
                        ]
                    )
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                Button("Quit Brighter") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
