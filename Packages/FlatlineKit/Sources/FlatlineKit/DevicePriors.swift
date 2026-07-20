import Foundation

/// Fallback drain rates before we've learned anything about this phone.
/// Rates are fraction of battery per hour under mixed real-world use.
public enum DevicePriors {
    /// Sensible default: a phone at moderate use loses ~8%/hr.
    public static let defaultRatePerHour = 0.08

    /// Model-specific overrides, keyed by hardware identifier prefix
    /// (e.g. "iPhone18" covers the iPhone 17 line). Bigger batteries drain
    /// slower in wall-clock terms; the differences are modest, so only
    /// clearly-different classes get entries.
    static let overridesByPrefix: [String: Double] = [
        "iPhone14": 0.10,  // iPhone 12/13 mini era small batteries
        "iPhone17": 0.08,
        "iPhone18": 0.07,  // iPhone 17 Pro Max class big batteries
    ]

    public static func ratePerHour(modelIdentifier: String) -> Double {
        for (prefix, rate) in overridesByPrefix where modelIdentifier.hasPrefix(prefix) {
            return rate
        }
        return defaultRatePerHour
    }
}
