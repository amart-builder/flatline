import Foundation

/// The output of the drain model: when we think the phone dies, and how sure we are.
public struct Estimate: Equatable, Sendable {
    public enum Confidence: String, Codable, Sendable {
        /// Prior only — we have little or no data on this phone yet.
        case low
        /// Some real drain data, but sparse or old.
        case medium
        /// Fresh drain data from the current discharge session.
        case high
    }

    /// When the battery is expected to hit 0%. Nil while charging.
    public let deathDate: Date?
    /// Drain rate as fraction of battery per hour (0.08 = 8%/hr).
    public let ratePerHour: Double
    public let confidence: Confidence
    public let isCharging: Bool

    public init(deathDate: Date?, ratePerHour: Double, confidence: Confidence, isCharging: Bool) {
        self.deathDate = deathDate
        self.ratePerHour = ratePerHour
        self.confidence = confidence
        self.isCharging = isCharging
    }
}
