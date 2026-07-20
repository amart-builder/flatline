import Foundation

/// One observation of the battery, taken whenever the app, widget, or an intent wakes up.
public struct BatterySample: Codable, Equatable, Sendable {
    public let timestamp: Date
    /// 0.0 ... 1.0. iOS 17+ quantizes third-party reads to 5% steps.
    public let level: Double
    public let isCharging: Bool

    public init(timestamp: Date, level: Double, isCharging: Bool) {
        self.timestamp = timestamp
        self.level = level
        self.isCharging = isCharging
    }
}
