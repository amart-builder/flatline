import SwiftUI
import FlatlineKit

/// The app's single main screen: a cardiac monitor for your battery.
struct DeathScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var estimate: Estimate?
    @State private var level: Double = 1.0
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            EKGView(level: estimate?.isCharging == true ? 1.0 : level)
                .frame(height: 130)
                .padding(.horizontal, 8)
            Spacer()
            readout
            Spacer()
            footer
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .preferredColorScheme(.dark)
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack {
            Text("FLATLINE")
                .font(.system(.subheadline, design: .monospaced).weight(.black))
                .foregroundStyle(.flatlineGreen)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.flatlineGreen.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var readout: some View {
        if let estimate {
            if estimate.isCharging {
                VStack(spacing: 12) {
                    Text("RESUSCITATING")
                        .font(.system(.title, design: .monospaced).weight(.black))
                        .foregroundStyle(.flatlineGreen)
                    Text("🔌 \(Int(level * 100))% and climbing")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.flatlineGreen.opacity(0.7))
                }
            } else if let deathDate = estimate.deathDate, let todText = estimate.timeOfDeathText {
                VStack(spacing: 10) {
                    Text("TIME OF DEATH: \(todText)")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(.flatlineGreen)
                    Text(timerInterval: Date.now...max(deathDate, .now), countsDown: true)
                        .font(.system(size: 64, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("\(Int(level * 100))% left · \(estimate.rateText)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.flatlineGreen.opacity(0.7))
                    if let hint = estimate.confidenceText {
                        Text(hint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                }
            } else {
                Text("Reading vitals…")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        } else {
            Text("Reading vitals…")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let estimate, let card = ShareCard(estimate: estimate, level: level) {
            ShareLink(
                item: card.render(),
                preview: SharePreview("Time of death: \(estimate.timeOfDeathText ?? "unknown")", image: card.render())
            ) {
                Label("Share the diagnosis", systemImage: "square.and.arrow.up")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.flatlineGreen, in: Capsule())
            }
        }
    }

    private func refresh() {
        if let sample = Battery.recordSample() {
            level = sample.level
        }
        estimate = Estimator.current()
    }
}

#Preview {
    DeathScreen()
}
