import WidgetKit
import SwiftUI

@main
struct FlatlineWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeathCountdownWidget()
    }
}

/// Phase 0 placeholder widget — proves the extension builds and installs.
/// Real timeline + live countdown land in Phase 3.
struct DeathCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeathCountdownWidget", provider: PlaceholderProvider()) { entry in
            VStack {
                Text("☠️")
                Text("soon")
                    .font(.caption.monospaced())
            }
            .containerBackground(.black, for: .widget)
            .foregroundStyle(.green)
        }
        .configurationDisplayName("Death Countdown")
        .description("How long your phone has left.")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}
