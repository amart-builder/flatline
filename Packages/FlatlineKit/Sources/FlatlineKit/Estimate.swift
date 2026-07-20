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
    /// Drain rate as fraction of battery per hour (0.08 = 8%/hr). While
    /// charging this still carries the learned discharge rate when known.
    public let ratePerHour: Double
    public let confidence: Confidence
    public let isCharging: Bool
    /// Battery level (0-1) at the latest sample. Nil with no data.
    public let level: Double?
    /// Timestamp of the latest sample, so consumers can judge staleness.
    public let latestSampleDate: Date?

    public init(
        deathDate: Date?,
        ratePerHour: Double,
        confidence: Confidence,
        isCharging: Bool,
        level: Double? = nil,
        latestSampleDate: Date? = nil
    ) {
        self.deathDate = deathDate
        self.ratePerHour = ratePerHour
        self.confidence = confidence
        self.isCharging = isCharging
        self.level = level
        self.latestSampleDate = latestSampleDate
    }

    /// When the battery is expected to reach `target` (0-1 fraction).
    /// The single source of truth for threshold math, so the app, widget,
    /// and Live Activity never disagree.
    public func date(whenLevelReaches target: Double) -> Date? {
        guard !isCharging, ratePerHour > 0,
              let level, let latestSampleDate, level > target else { return nil }
        let hours = (level - target) / ratePerHour
        return latestSampleDate.addingTimeInterval(hours * 3600)
    }
}

// MARK: - Display formatting (one place, so every surface agrees)

extension Estimate {
    /// Death time rounded to 5 minutes — honest fuzz, e.g. "3:40 PM".
    /// Nil while charging or with no data at all.
    public var timeOfDeathText: String? {
        guard let deathDate else { return nil }
        let rounded = Date(timeIntervalSinceReferenceDate:
            (deathDate.timeIntervalSinceReferenceDate / 300).rounded() * 300)
        return rounded.formatted(date: .omitted, time: .shortened)
    }

    /// "bleeding 11%/hr"
    public var rateText: String {
        "bleeding \(Int((ratePerHour * 100).rounded()))%/hr"
    }

    public var confidenceText: String? {
        switch confidence {
        case .low: return "rough guess — still learning this phone"
        case .medium: return "estimate from past behavior"
        case .high: return nil  // fresh data speaks for itself
        }
    }
}
