import SwiftUI
import FlatlineKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var threshold = FlatlineDefaults.threshold
    @State private var showSetupGuide = false

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
                    Text("Set your Shortcuts automation to the same number (Settings can't change the automation for you).")
                }

                Section {
                    Button("Automation setup guide") { showSetupGuide = true }
                } footer: {
                    Text("Extra credit: add automations at 15%, 10%, and 5% pointing at Start Death Watch (each one sharpens the countdown), and one for charger-connected pointing at Cancel Death Watch.")
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
            .fullScreenCover(isPresented: $showSetupGuide) {
                OnboardingFlow(startAtSteps: true)
            }
        }
    }
}

#Preview {
    SettingsView()
}
