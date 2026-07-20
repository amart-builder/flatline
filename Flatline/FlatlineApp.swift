import SwiftUI
import FlatlineKit

@main
struct FlatlineApp: App {
    var body: some Scene {
        WindowGroup {
            HelloDeathView()
        }
    }
}

/// Phase 0 placeholder — proves the app runs on device and can read the battery.
/// Replaced by DeathScreen in Phase 2.
struct HelloDeathView: View {
    @State private var level: Double = -1
    @State private var charging = false

    var body: some View {
        VStack(spacing: 16) {
            Text("FLATLINE")
                .font(.system(size: 44, weight: .black, design: .monospaced))
            if level >= 0 {
                Text("Battery: \(Int(level * 100))%\(charging ? " 🔌" : "")")
                    .font(.title2.monospacedDigit())
            } else {
                Text("Reading battery…")
                    .foregroundStyle(.secondary)
            }
            Text("Your phone's death will be announced.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear(perform: readBattery)
    }

    private func readBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        level = Double(UIDevice.current.batteryLevel)
        charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
    }
}
