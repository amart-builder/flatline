#if canImport(UIKit)
import UIKit

/// Shared battery access for the app, widget, and intents: read the current
/// state, record it, and get a fresh estimate — one implementation so every
/// surface samples and predicts identically.
public enum BatteryReader {
    /// Hardware identifier like "iPhone18,2" — used for the drain-rate prior.
    public static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    public static func currentSample(now: Date = .now) -> BatterySample? {
        #if targetEnvironment(simulator)
        // Simulators report battery level as unknown; fake a dying phone so
        // the UI is exercisable in dev.
        return BatterySample(timestamp: now, level: 0.19, isCharging: false)
        #else
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return nil }  // -1 = unknown
        let state = UIDevice.current.batteryState
        return BatterySample(
            timestamp: now,
            level: Double(level),
            isCharging: state == .charging || state == .full
        )
        #endif
    }

    /// Records the current state into the shared store. Call on every wake —
    /// app foregrounds, widget refreshes, and intent runs are the only
    /// moments iOS gives us, and each one is free telemetry.
    @discardableResult
    public static func recordSample(now: Date = .now) -> BatterySample? {
        guard let sample = currentSample(now: now) else { return nil }
        SampleStore().append(sample, now: now)
        return sample
    }

    /// Fresh estimate from everything stored so far.
    public static func estimate(now: Date = .now) -> Estimate {
        DrainModel.estimate(
            samples: SampleStore().load(),
            now: now,
            priorRatePerHour: DevicePriors.ratePerHour(modelIdentifier: modelIdentifier)
        )
    }
}
#endif
