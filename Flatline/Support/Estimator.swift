import Foundation
import FlatlineKit

/// One-stop facade the UI and intents call: fresh estimate from stored samples.
enum Estimator {
    static func current(now: Date = .now) -> Estimate {
        DrainModel.estimate(
            samples: SampleStore().load(),
            now: now,
            priorRatePerHour: DevicePriors.ratePerHour(modelIdentifier: Battery.modelIdentifier)
        )
    }
}
