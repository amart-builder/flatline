#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Shared Live Activity contract between the app (which starts the activity)
/// and the widget extension (which renders it).
public struct DeathWatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the phone is expected to die. The system renders the live
        /// countdown to this date; no updates needed for the tick.
        public var deathDate: Date
        /// Battery level 0-1 at the last estimate.
        public var level: Double
        /// Drain rate as fraction/hr.
        public var ratePerHour: Double

        public init(deathDate: Date, level: Double, ratePerHour: Double) {
            self.deathDate = deathDate
            self.level = level
            self.ratePerHour = ratePerHour
        }
    }

    public init() {}
}
#endif
