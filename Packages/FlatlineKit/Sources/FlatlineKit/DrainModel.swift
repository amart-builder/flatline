import Foundation

/// Pure estimation logic: battery samples in, death estimate out.
///
/// Design constraints it works around:
/// - iOS quantizes third-party battery reads to 5% steps, so the rate must be
///   fit across level *transitions*, not raw values.
/// - Charging must fence off segments so charge periods never pollute drain rates.
/// - New users have no data, so a device-model prior fills in until real
///   samples accumulate.
public enum DrainModel {

    /// Samples closer together than this can't give a meaningful rate.
    static let minRateInterval: TimeInterval = 10 * 60
    /// Only samples this recent count as "the current discharge session".
    static let recentWindow: TimeInterval = 6 * 3600
    /// Ignore historical rates from segments older than this.
    static let historyWindow: TimeInterval = 14 * 24 * 3600
    /// Rates outside this band are treated as noise (fraction/hr).
    static let plausibleRate = 0.005...0.60

    // MARK: Public API

    /// - Parameters:
    ///   - samples: chronological battery observations (deduped or not; tolerated).
    ///   - now: current time (injectable for tests).
    ///   - priorRatePerHour: device-model fallback rate.
    public static func estimate(
        samples: [BatterySample],
        now: Date,
        priorRatePerHour: Double = DevicePriors.defaultRatePerHour
    ) -> Estimate {
        let clean = sanitized(samples)

        guard let latest = clean.last else {
            return Estimate(
                deathDate: nil,
                ratePerHour: priorRatePerHour,
                confidence: .low,
                isCharging: false
            )
        }

        if latest.isCharging {
            return Estimate(deathDate: nil, ratePerHour: 0, confidence: .high, isCharging: true)
        }

        let segments = dischargeSegments(clean)
        let currentSegment = segments.last ?? []

        let recent = rate(of: currentSegment.filter { now.timeIntervalSince($0.timestamp) <= recentWindow })
        let historical = historicalRate(segments: segments.dropLast(), now: now)

        let (blended, confidence) = blend(
            recent: recent,
            historical: historical,
            prior: priorRatePerHour
        )

        let hoursLeft = latest.level / blended
        // Anchor from the latest sample, not `now`: the phone kept draining since.
        let deathDate = latest.timestamp.addingTimeInterval(hoursLeft * 3600)

        return Estimate(
            deathDate: max(deathDate, now),
            ratePerHour: blended,
            confidence: confidence,
            isCharging: false
        )
    }

    // MARK: Internals (exposed for tests)

    /// Drops out-of-order timestamps (clock changes) and exact duplicates.
    static func sanitized(_ samples: [BatterySample]) -> [BatterySample] {
        var result: [BatterySample] = []
        for sample in samples {
            if let last = result.last {
                guard sample.timestamp > last.timestamp else { continue }
            }
            result.append(sample)
        }
        return result
    }

    /// Splits samples into runs of pure discharge. A charging flag or any
    /// level increase ends the current segment.
    static func dischargeSegments(_ samples: [BatterySample]) -> [[BatterySample]] {
        var segments: [[BatterySample]] = []
        var current: [BatterySample] = []
        for sample in samples {
            if sample.isCharging {
                if !current.isEmpty { segments.append(current); current = [] }
                continue
            }
            if let last = current.last, sample.level > last.level + 0.001 {
                segments.append(current)
                current = []
            }
            current.append(sample)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    /// Fits a drain rate (fraction/hr) to one discharge segment.
    ///
    /// Because levels are quantized, the fit uses the first and last sample of
    /// each observed *level*, measuring time across level transitions. Returns
    /// nil when the segment spans fewer than two distinct levels or too little time.
    static func rate(of segment: [BatterySample]) -> Double? {
        guard segment.count >= 2,
              let first = segment.first, let last = segment.last else { return nil }

        let levelDrop = first.level - last.level
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard levelDrop > 0.001, elapsed >= minRateInterval else { return nil }

        let perHour = levelDrop / (elapsed / 3600)
        guard plausibleRate.contains(perHour) else { return nil }
        return perHour
    }

    /// Average rate across completed past segments inside the history window.
    static func historicalRate(segments: ArraySlice<[BatterySample]>, now: Date) -> Double? {
        let rates = segments.compactMap { segment -> Double? in
            guard let start = segment.first?.timestamp,
                  now.timeIntervalSince(start) <= historyWindow else { return nil }
            return rate(of: segment)
        }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Weighted blend of the three sources. Fresh data dominates when present.
    static func blend(recent: Double?, historical: Double?, prior: Double) -> (Double, Estimate.Confidence) {
        switch (recent, historical) {
        case let (.some(r), .some(h)):
            return (0.7 * r + 0.2 * h + 0.1 * prior, .high)
        case let (.some(r), .none):
            return (0.7 * r + 0.3 * prior, .high)
        case let (.none, .some(h)):
            return (0.6 * h + 0.4 * prior, .medium)
        case (.none, .none):
            return (prior, .low)
        }
    }
}
