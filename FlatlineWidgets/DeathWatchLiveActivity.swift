import ActivityKit
import WidgetKit
import SwiftUI
import FlatlineKit

/// The star of the show: the Lock Screen banner + Dynamic Island countdown
/// that appears when the battery crosses the death-watch threshold.
struct DeathWatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeathWatchAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("☠️")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.level * 100))%")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.flatlineGreen)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("TIME OF DEATH \(timeText(context.state.deathDate))")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.flatlineGreen)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    countdown(context, size: 34)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Text("☠️")
            } compactTrailing: {
                countdown(context, size: 14)
                    .frame(maxWidth: 60)
                    .foregroundStyle(Color.flatlineGreen)
            } minimal: {
                Text("☠️")
            }
        }
    }

    // MARK: Lock Screen banner

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<DeathWatchAttributes>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("FLATLINE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.flatlineGreen.opacity(0.7))
                Spacer()
                Text("\(Int(context.state.level * 100))% left")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.flatlineGreen.opacity(0.7))
            }
            Text("TIME OF DEATH: \(timeText(context.state.deathDate))")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(Color.flatlineGreen)
            countdown(context, size: 40)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(Color.flatlineGreen)
    }

    // MARK: Pieces

    private func countdown(_ context: ActivityViewContext<DeathWatchAttributes>, size: CGFloat) -> some View {
        Text(timerInterval: Date.now...max(context.state.deathDate, .now), countsDown: true)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.white)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private func timeText(_ date: Date) -> String {
        let rounded = Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 300).rounded() * 300)
        return rounded.formatted(date: .omitted, time: .shortened)
    }
}
