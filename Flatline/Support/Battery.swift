import UIKit
import FlatlineKit

/// App-side battery access: reads the current state and records samples.
enum Battery {
    /// Hardware identifier like "iPhone18,2" — used for the drain-rate prior.
    static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    static func currentSample(now: Date = .now) -> BatterySample? {
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

    /// Records the current state into the shared store. Call on every wake.
    @discardableResult
    static func recordSample() -> BatterySample? {
        guard let sample = currentSample() else { return nil }
        SampleStore().append(sample)
        return sample
    }
}
