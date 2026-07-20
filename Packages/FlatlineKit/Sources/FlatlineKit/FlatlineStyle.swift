import SwiftUI

extension Color {
    /// Phosphor-monitor green, the whole app's identity color.
    public static let flatlineGreen = Color(red: 0.15, green: 1.0, blue: 0.35)
}

extension ShapeStyle where Self == Color {
    /// Lets `.foregroundStyle(.flatlineGreen)` dot-syntax resolve.
    public static var flatlineGreen: Color { .flatlineGreen }
}
