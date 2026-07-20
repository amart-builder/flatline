import SwiftUI
import FlatlineKit

/// Shared defaults readable by the app, widget, and intents.
enum FlatlineDefaults {
    static let suite = UserDefaults(suiteName: SampleStore.appGroupID) ?? .standard
    static let thresholdKey = "deathwatch.threshold"

    /// Battery fraction below which the death watch is meant to fire (0.20 = 20%).
    static var threshold: Double {
        get {
            let value = suite.double(forKey: thresholdKey)
            return value > 0 ? value : 0.20
        }
        set { suite.set(newValue, forKey: thresholdKey) }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var threshold = FlatlineDefaults.threshold

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Death watch starts at", selection: $threshold) {
                        ForEach([0.30, 0.25, 0.20, 0.15, 0.10], id: \.self) { value in
                            Text("\(Int(value * 100))%").tag(value)
                        }
                    }
                    .onChange(of: threshold) { _, newValue in
                        FlatlineDefaults.threshold = newValue
                    }
                } footer: {
                    Text("Set your Shortcuts automation to the same number — Settings can't change the automation for you. Setup guide coming in onboarding.")
                }

                Section {
                    Link("Source code (it's open)", destination: URL(string: "https://github.com/amart-builder/flatline")!)
                } footer: {
                    Text("No accounts. No tracking. No network. Just death.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
