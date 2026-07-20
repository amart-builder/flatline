import SwiftUI

/// Scrolling cardiac-monitor trace. The heartbeat slows and weakens as the
/// battery drops; at zero it flatlines.
struct EKGView: View {
    /// 0.0 ... 1.0 battery level driving the pulse.
    var level: Double
    var color: Color = .flatlineGreen

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                var path = Path()
                let midY = size.height / 2
                let speed = 60.0  // points per second the trace scrolls
                let beatWidth = 140.0  // one heartbeat cycle in points
                let amplitude = max(0.06, level) * midY * 0.9

                for x in stride(from: 0.0, through: size.width, by: 2) {
                    let phase = ((x + t * speed) / beatWidth).truncatingRemainder(dividingBy: 1)
                    let y = midY - amplitude * pulse(phase)
                    if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(color), lineWidth: 2)
            }
        }
        .drawingGroup()
    }

    /// A PQRST-ish heartbeat shape over one 0-1 phase; 0 elsewhere (baseline).
    /// Level scales are applied by the caller via amplitude.
    private func pulse(_ phase: Double) -> Double {
        guard level > 0.005 else { return 0 }  // dead: flat line
        switch phase {
        case 0.10..<0.16: return 0.15 * sin((phase - 0.10) / 0.06 * .pi)        // P wave
        case 0.22..<0.26: return -0.25 * sin((phase - 0.22) / 0.04 * .pi)       // Q dip
        case 0.26..<0.34: return sin((phase - 0.26) / 0.08 * .pi)               // R spike
        case 0.34..<0.40: return -0.35 * sin((phase - 0.34) / 0.06 * .pi)       // S dip
        case 0.48..<0.60: return 0.28 * sin((phase - 0.48) / 0.12 * .pi)        // T wave
        default: return 0
        }
    }
}

extension Color {
    /// Phosphor-monitor green, the whole app's identity color.
    static let flatlineGreen = Color(red: 0.15, green: 1.0, blue: 0.35)
}

extension ShapeStyle where Self == Color {
    /// Lets `.foregroundStyle(.flatlineGreen)` dot-syntax resolve.
    static var flatlineGreen: Color { .flatlineGreen }
}

#Preview {
    VStack {
        EKGView(level: 0.9).frame(height: 120)
        EKGView(level: 0.2).frame(height: 120)
        EKGView(level: 0.0).frame(height: 120)
    }
    .background(.black)
}
