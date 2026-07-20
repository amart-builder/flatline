import SwiftUI
import FlatlineKit

/// The one-time setup: iOS won't let us create the battery automation for the
/// user, so this flow hand-holds them through Shortcuts and then PROVES the
/// wiring works before declaring the death watch armed.
struct OnboardingFlow: View {
    @Environment(\.dismiss) private var dismiss
    /// Jump straight to the instructions when reopened from Settings.
    var startAtSteps = false
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            pitch.tag(0)
            AutomationSetupView(next: { page = 2 }).tag(1)
            ArmingView(done: finish).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(.black)
        .preferredColorScheme(.dark)
        .onAppear { if startAtSteps { page = 1 } }
    }

    private var pitch: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("☠️")
                .font(.system(size: 72))
            Text("Your phone is going to die.")
                .font(.system(.title2, design: .monospaced).weight(.black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Flatline tells you when. A countdown appears on your Lock Screen the moment your battery starts flatlining.")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                page = 1
            } label: {
                Text("Set it up (about 60 seconds)")
                    .font(.system(.callout, design: .monospaced).weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.flatlineGreen, in: Capsule())
            }
            Button("Skip for now") { finish() }
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.gray)
                .padding(.bottom, 24)
        }
        .padding(24)
    }

    private func finish() {
        FlatlineDefaults.hasOnboarded = true
        dismiss()
    }
}

/// The Shortcuts walkthrough. Personal automations cannot be created by apps,
/// full stop — so the steps have to be dead simple and honest.
struct AutomationSetupView: View {
    var next: () -> Void

    private let steps: [(String, String)] = [
        ("1", "Open the Shortcuts app"),
        ("2", "Tap Automation at the bottom"),
        ("3", "Tap + to make a new automation"),
        ("4", "Choose Battery Level"),
        ("5", "Set the slider to 20% and pick Falls Below 20%"),
        ("6", "Pick Run Immediately, then tap Next"),
        ("7", "Search Flatline and pick Start Death Watch"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WIRE IT UP")
                .font(.system(.title3, design: .monospaced).weight(.black))
                .foregroundStyle(Color.flatlineGreen)
                .padding(.bottom, 4)
            Text("One Shortcuts automation makes the countdown automatic. iOS makes you do this part yourself.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.gray)
                .padding(.bottom, 20)

            ForEach(steps, id: \.0) { number, text in
                HStack(alignment: .top, spacing: 12) {
                    Text(number)
                        .font(.system(.footnote, design: .monospaced).weight(.black))
                        .foregroundStyle(.black)
                        .frame(width: 22, height: 22)
                        .background(Color.flatlineGreen, in: Circle())
                    Text(text)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 12)
            }

            Spacer()

            VStack(spacing: 12) {
                Link(destination: URL(string: "shortcuts://")!) {
                    Text("Open Shortcuts")
                        .font(.system(.callout, design: .monospaced).weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.flatlineGreen, in: Capsule())
                }
                Button {
                    next()
                } label: {
                    Text("Done, automation created")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Color.flatlineGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Capsule().stroke(Color.flatlineGreen.opacity(0.5)))
                }
            }
            .padding(.bottom, 16)
        }
        .padding(24)
    }
}

/// Verification: don't claim the watch is armed until the intent has actually
/// fired once. The user runs their new automation manually as a test; the
/// intent stamps a shared flag; this screen sees it and flips.
struct ArmingView: View {
    var done: () -> Void
    @State private var armedSince: Date?
    private let openedAt = Date.now

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 24) {
                Spacer()
                if isArmed {
                    Text("☠️")
                        .font(.system(size: 72))
                    Text("ARMED")
                        .font(.system(.largeTitle, design: .monospaced).weight(.black))
                        .foregroundStyle(Color.flatlineGreen)
                    Text("Your phone's death will now be announced.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Button {
                        done()
                    } label: {
                        Text("Finish")
                            .font(.system(.callout, design: .monospaced).weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.flatlineGreen, in: Capsule())
                    }
                    .padding(.bottom, 24)
                } else {
                    EKGView(level: 0.5)
                        .frame(height: 80)
                    Text("waiting for first signal…")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.flatlineGreen)
                    Text("Test it: in Shortcuts, open your new automation and tap Run. The moment it reaches us, this screen flips.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Button("Verify later") { done() }
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.gray)
                        .padding(.bottom, 24)
                }
            }
            .padding(24)
        }
    }

    private var isArmed: Bool {
        guard let fired = FlatlineDefaults.lastAutomationFiredAt else { return false }
        // Only signals from THIS setup session count, with a little slack in
        // case the automation fired moments before the screen appeared.
        return fired > openedAt.addingTimeInterval(-120)
    }
}

#Preview {
    OnboardingFlow()
}
