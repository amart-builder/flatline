import WidgetKit
import SwiftUI
import FlatlineKit

@main
struct FlatlineWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeathCountdownWidget()
        DeathWatchLiveActivity()
    }
}

struct DeathEntry: TimelineEntry {
    let date: Date
    let estimate: Estimate
    let level: Double?
}

struct DeathProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeathEntry {
        DeathEntry(
            date: .now,
            estimate: Estimate(
                deathDate: .now.addingTimeInterval(2 * 3600 + 14 * 60),
                ratePerHour: 0.11, confidence: .high, isCharging: false,
                level: 0.19, latestSampleDate: .now
            ),
            level: 0.19
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DeathEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeathEntry>) -> Void) {
        let entry = currentEntry()
        // Widget refreshes are rationed (~40-70/day). Spend them where they
        // matter: denser as the battery gets low, sparse when it's healthy.
        let minutes: Double
        switch entry.level ?? 1.0 {
        case ..<0.30: minutes = 15
        case ..<0.60: minutes = 30
        default: minutes = 60
        }
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(minutes * 60))))
    }

    /// Every widget wake records a sample — free telemetry for the model.
    private func currentEntry() -> DeathEntry {
        let sample = BatteryReader.recordSample()
        return DeathEntry(date: .now, estimate: BatteryReader.estimate(), level: sample?.level)
    }
}

struct DeathCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeathCountdownWidget", provider: DeathProvider()) { entry in
            DeathWidgetView(entry: entry)
        }
        .configurationDisplayName("Death Countdown")
        .description("How long your phone has left.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct DeathWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeathEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inline
            case .accessoryRectangular:
                rectangular
            case .accessoryCircular:
                circular
            default:
                small
            }
        }
        .containerBackground(.black, for: .widget)
    }

    // MARK: Small (home screen)

    private var small: some View {
        VStack(spacing: 6) {
            if entry.estimate.isCharging {
                Text("🔌")
                    .font(.title)
                Text("RESURRECTING")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.flatlineGreen)
            } else if let deathDate = entry.estimate.deathDate, let tod = entry.estimate.timeOfDeathText {
                Text("☠️ \(tod)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.flatlineGreen)
                    .minimumScaleFactor(0.7)
                Text(timerInterval: entry.date...max(deathDate, entry.date), countsDown: true)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                if let level = entry.level {
                    Text("\(Int(level * 100))% left")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.flatlineGreen.opacity(0.7))
                }
            } else {
                Text("☠️")
                    .font(.title)
                Text("taking vitals…")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
        .padding(4)
    }

    // MARK: Lock screen accessories

    private var inline: some View {
        Group {
            if entry.estimate.isCharging {
                Text("🔌 resurrecting")
            } else if let tod = entry.estimate.timeOfDeathText {
                Text("☠️ dies ~\(tod)")
            } else {
                Text("☠️ taking vitals…")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.estimate.isCharging {
                Text("RESURRECTING 🔌")
                    .font(.system(.headline, design: .monospaced))
            } else if let deathDate = entry.estimate.deathDate, let tod = entry.estimate.timeOfDeathText {
                Text("TIME OF DEATH \(tod)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .minimumScaleFactor(0.8)
                Text(timerInterval: entry.date...max(deathDate, entry.date), countsDown: true)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                if let level = entry.level {
                    Text("\(Int(level * 100))% · \(entry.estimate.rateText)")
                        .font(.system(size: 10, design: .monospaced))
                        .opacity(0.7)
                }
            } else {
                Text("☠️ taking vitals…")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var circular: some View {
        Gauge(value: entry.level ?? 0) {
            Text("☠️")
        } currentValueLabel: {
            if let level = entry.level {
                Text("\(Int(level * 100))")
                    .font(.system(.body, design: .monospaced).weight(.bold))
            } else {
                Text("?")
            }
        }
        .gaugeStyle(.accessoryCircular)
    }
}

#Preview(as: .systemSmall) {
    DeathCountdownWidget()
} timeline: {
    DeathEntry(
        date: .now,
        estimate: Estimate(
            deathDate: .now.addingTimeInterval(2 * 3600 + 14 * 60),
            ratePerHour: 0.11, confidence: .high, isCharging: false,
            level: 0.19, latestSampleDate: .now
        ),
        level: 0.19
    )
}
