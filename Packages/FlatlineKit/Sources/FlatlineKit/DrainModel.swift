import Foundation

/// Pure estimation logic: battery samples in, death estimate out.
///
/// Design constraints it works around:
/// - iOS quantizes third-party battery reads to 5% steps, so rates are fit
///   between observed level *transitions*, not raw endpoint values.
/// - Charging must fence off segments so charge periods never pollute drain
///   rates. A long gap between samples is also a fence: the phone may have
///   charged and drained back down while we weren't looking.
/// - New users have no data, so a device-model prior fills in until real
///   samples accumulate.
/// - Timestamps can be garbage in both directions (clock changes).
public enum DrainModel {

    /// Samples closer together than this can't give a meaningful rate.
    static let minRateInterval: TimeInterval = 10 * 60
    /// Only samples this recent count as "the current discharge session".
    static let recentWindow: TimeInterval = 6 * 3600
    /// Ignore historical rates from segments older than this.
    static let historyWindow: TimeInterval = 14 * 24 * 3600
    /// A gap between samples longer than this ends a segment — a hidden
    /// charge could be lurking inside it.
    static let maxSegmentGap: TimeInterval = 2 * 3600
    /// A charging read older than this no longer proves the phone is charging.
    static let chargingStaleness: TimeInterval = 2 * 3600
    /// Samples stamped further in the future than this are clock garbage.
    static let futureTolerance: TimeInterval = 5 * 60
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
        let clean = sanitized(samples, now: now)

        guard let latest = clean.last else {
            return Estimate(deathDate: nil, ratePerHour: priorRatePerHour, confidence: .low, isCharging: false)
        }

        let segments = dischargeSegments(clean)

        let recentSamples = (segments.last ?? []).filter { now.timeIntervalSince($0.timestamp) <= recentWindow }
        let recent = fit(of: recentSamples)
        // A completed-but-stale segment still carries signal: when nothing is
        // recent, let the last segment count as history instead of dropping it.
        let historySegments = recent == nil ? segments[...] : segments.dropLast()
        let historical = historicalRate(segments: historySegments, now: now)

        let (blended, confidence) = blend(recent: recent, historical: historical, prior: priorRatePerHour)

        let sampleAge = now.timeIntervalSince(latest.timestamp)
        if latest.isCharging {
            if sampleAge <= chargingStaleness {
                return Estimate(
                    deathDate: nil, ratePerHour: blended, confidence: confidence,
                    isCharging: true, level: latest.level, latestSampleDate: latest.timestamp
                )
            }
            // Stale charging read: we genuinely don't know the state anymore.
            // Assume it was unplugged around then and guess from the prior.
            let hoursLeft = latest.level / priorRatePerHour
            return Estimate(
                deathDate: max(latest.timestamp.addingTimeInterval(hoursLeft * 3600), now),
                ratePerHour: priorRatePerHour, confidence: .low,
                isCharging: false, level: latest.level, latestSampleDate: latest.timestamp
            )
        }

        let hoursLeft = latest.level / blended
        // Anchor from the latest sample, not `now`: the phone kept draining since.
        let deathDate = latest.timestamp.addingTimeInterval(hoursLeft * 3600)

        return Estimate(
            deathDate: max(deathDate, now), ratePerHour: blended, confidence: confidence,
            isCharging: false, level: latest.level, latestSampleDate: latest.timestamp
        )
    }

    // MARK: Internals (exposed for tests)

    /// Drops out-of-order timestamps, exact duplicates, and future-stamped
    /// clock garbage. A future sample must not become a poison pill that
    /// out-orders every real sample after it.
    static func sanitized(_ samples: [BatterySample], now: Date) -> [BatterySample] {
        var result: [BatterySample] = []
        for sample in samples {
            guard sample.timestamp.timeIntervalSince(now) <= futureTolerance else { continue }
            if let last = result.last {
                guard sample.timestamp > last.timestamp else { continue }
            }
            result.append(sample)
        }
        return result
    }

    /// Splits samples into runs of trustworthy discharge. A charging flag,
    /// any level increase, or a long sample gap ends the current segment.
    static func dischargeSegments(_ samples: [BatterySample]) -> [[BatterySample]] {
        var segments: [[BatterySample]] = []
        var current: [BatterySample] = []
        func closeSegment() {
            if !current.isEmpty { segments.append(current); current = [] }
        }
        for sample in samples {
            if sample.isCharging {
                closeSegment()
                continue
            }
            if let last = current.last {
                if sample.level > last.level + 0.001 { closeSegment() }
                else if sample.timestamp.timeIntervalSince(last.timestamp) > maxSegmentGap { closeSegment() }
            }
            current.append(sample)
        }
        closeSegment()
        return segments
    }

    /// A fitted drain rate and how well-anchored it is.
    struct RateFit: Equatable {
        let perHour: Double
        /// Number of observed level transitions backing the fit. With >= 2,
        /// quantization phase error is bounded by one sampling interval over
        /// the whole span; with 1, the endpoint fit can be off by up to ~2x.
        let transitions: Int
    }

    /// Fits a drain rate (fraction/hr) to one discharge segment.
    ///
    /// Levels are quantized, so the primary fit runs transition-to-transition:
    /// from the first sample at which a level drop was observed to the last.
    /// With only one transition it falls back to an endpoint fit.
    static func fit(of segment: [BatterySample]) -> RateFit? {
        guard segment.count >= 2, let first = segment.first, let last = segment.last else { return nil }

        let transitions = zip(segment, segment.dropFirst())
            .filter { $1.level < $0.level - 0.001 }
            .map { $1 }
        guard let firstTransition = transitions.first, let lastTransition = transitions.last else { return nil }

        if transitions.count >= 2 {
            let drop = firstTransition.level - lastTransition.level
            let elapsed = lastTransition.timestamp.timeIntervalSince(firstTransition.timestamp)
            if drop > 0.001, elapsed >= minRateInterval {
                let perHour = drop / (elapsed / 3600)
                if plausibleRate.contains(perHour) {
                    return RateFit(perHour: perHour, transitions: transitions.count)
                }
            }
        }

        let drop = first.level - last.level
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard drop > 0.001, elapsed >= minRateInterval else { return nil }
        let perHour = drop / (elapsed / 3600)
        guard plausibleRate.contains(perHour) else { return nil }
        return RateFit(perHour: perHour, transitions: 1)
    }

    /// Average rate across past segments inside the history window.
    static func historicalRate(segments: ArraySlice<[BatterySample]>, now: Date) -> Double? {
        let rates = segments.compactMap { segment -> Double? in
            guard let start = segment.first?.timestamp,
                  now.timeIntervalSince(start) <= historyWindow else { return nil }
            return fit(of: segment)?.perHour
        }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Weighted blend of the three sources. Fresh data dominates when present;
    /// `.high` confidence requires a well-anchored recent fit (>= 2 transitions).
    static func blend(recent: RateFit?, historical: Double?, prior: Double) -> (Double, Estimate.Confidence) {
        switch (recent, historical) {
        case let (.some(r), .some(h)):
            return (0.7 * r.perHour + 0.2 * h + 0.1 * prior, r.transitions >= 2 ? .high : .medium)
        case let (.some(r), .none):
            return (0.7 * r.perHour + 0.3 * prior, r.transitions >= 2 ? .high : .medium)
        case let (.none, .some(h)):
            return (0.6 * h + 0.4 * prior, .medium)
        case (.none, .none):
            return (prior, .low)
        }
    }
}
