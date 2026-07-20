import SwiftUI
import FlatlineKit

/// The viral artifact: a "certificate of death (pending)" image for sharing.
struct ShareCard {
    let timeOfDeath: String
    let countdownText: String
    let levelText: String
    let rateText: String

    init?(estimate: Estimate, level: Double, now: Date = .now) {
        guard let deathDate = estimate.deathDate, let todText = estimate.timeOfDeathText else { return nil }
        timeOfDeath = todText
        let remaining = max(0, deathDate.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        countdownText = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        levelText = "\(Int(level * 100))%"
        rateText = estimate.rateText
    }

    @MainActor
    func render() -> Image {
        let renderer = ImageRenderer(content: CardView(card: self))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else {
            return Image(systemName: "bolt.slash")
        }
        return Image(uiImage: uiImage)
    }
}

private struct CardView: View {
    let card: ShareCard

    var body: some View {
        VStack(spacing: 18) {
            Text("CERTIFICATE OF DEATH")
                .font(.system(size: 18, weight: .black, design: .monospaced))
            Text("(pending)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.gray)

            EKGStaticLine()
                .frame(height: 44)

            VStack(spacing: 6) {
                row("PATIENT", "this iPhone")
                row("CONDITION", "\(card.levelText) · \(card.rateText)")
                row("TIME OF DEATH", card.timeOfDeath)
                row("TIME REMAINING", card.countdownText)
            }

            Text("FLATLINE · a countdown to your phone's death")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .foregroundStyle(Color.flatlineGreen)
        .padding(28)
        .frame(width: 360)
        .background(.black)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
        }
    }
}

/// A single frozen heartbeat trailing into a flat line, for the card.
private struct EKGStaticLine: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let midY = size.height / 2
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: size.width * 0.35, y: midY))
            path.addLine(to: CGPoint(x: size.width * 0.40, y: midY + 6))
            path.addLine(to: CGPoint(x: size.width * 0.45, y: midY - size.height * 0.42))
            path.addLine(to: CGPoint(x: size.width * 0.50, y: midY + 10))
            path.addLine(to: CGPoint(x: size.width * 0.55, y: midY))
            path.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(path, with: .color(.flatlineGreen), lineWidth: 2)
        }
    }
}

#Preview {
    if let card = ShareCard(
        estimate: Estimate(deathDate: .now.addingTimeInterval(6500), ratePerHour: 0.11, confidence: .high, isCharging: false),
        level: 0.19
    ) {
        card.render()
    }
}
