import XCTest
@testable import FlatlineKit

final class DrainModelTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func sample(_ minutes: Double, _ level: Double, charging: Bool = false) -> BatterySample {
        BatterySample(timestamp: t0.addingTimeInterval(minutes * 60), level: level, isCharging: charging)
    }

    // MARK: Steady drain

    func testSteadyDrainPredictsDeathTime() {
        // 10%/hr: 50% → 40% over one hour, quantized 5% steps.
        let samples = [
            sample(0, 0.50), sample(30, 0.45), sample(60, 0.40),
        ]
        let now = t0.addingTimeInterval(3600)
        let estimate = DrainModel.estimate(samples: samples, now: now, priorRatePerHour: 0.10)

        XCTAssertFalse(estimate.isCharging)
        XCTAssertEqual(estimate.confidence, .high)
        XCTAssertEqual(estimate.ratePerHour, 0.10, accuracy: 0.005)
        // 40% at 10%/hr → dead ~4h after the last sample.
        let expected = t0.addingTimeInterval(3600 + 4 * 3600)
        XCTAssertEqual(estimate.deathDate!.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 15 * 60)
    }

    // MARK: Quantization

    func testQuantizedStepsGiveRateAcrossTransitions() {
        // Level sits at 0.40 for several reads, then steps to 0.35 —
        // the rate must come from the transition, not read noise.
        let samples = [
            sample(0, 0.40), sample(10, 0.40), sample(20, 0.40),
            sample(30, 0.35), sample(40, 0.35),
            sample(60, 0.30),
        ]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(3600))
        // 10% drop over 60 min = ~10%/hr.
        XCTAssertEqual(estimate.ratePerHour, 0.10, accuracy: 0.03)
        XCTAssertEqual(estimate.confidence, .high)
    }

    func testSingleLevelNoTransitionFallsBackToPrior() {
        // All reads at the same level — no transition, no rate.
        let samples = [sample(0, 0.20), sample(10, 0.20), sample(20, 0.20)]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(1800), priorRatePerHour: 0.08)
        XCTAssertEqual(estimate.ratePerHour, 0.08, accuracy: 0.001)
        XCTAssertEqual(estimate.confidence, .low)
    }

    // MARK: Charging

    func testChargingReturnsNoDeathDate() {
        let samples = [sample(0, 0.20), sample(30, 0.50, charging: true)]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(1800))
        XCTAssertTrue(estimate.isCharging)
        XCTAssertNil(estimate.deathDate)
    }

    func testChargePeriodDoesNotPolluteDrainRate() {
        // Slow 5%/hr drain, a charge to 80%, then slow drain again.
        // A naive fit across the charge would produce garbage.
        let samples = [
            sample(0, 0.30), sample(60, 0.25),
            sample(70, 0.60, charging: true), sample(80, 0.80, charging: true),
            sample(90, 0.80), sample(150, 0.75), sample(210, 0.70),
        ]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(211 * 60))
        XCTAssertFalse(estimate.isCharging)
        XCTAssertEqual(estimate.ratePerHour, 0.05, accuracy: 0.02)
    }

    func testLevelIncreaseWithoutFlagFencesSegment() {
        // Level jumps up without an isCharging flag (missed the charge window).
        let samples = [
            sample(0, 0.20), sample(60, 0.15),
            sample(120, 0.90),  // clearly charged in between
            sample(180, 0.85),
        ]
        let segments = DrainModel.dischargeSegments(samples)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[1].first?.level, 0.90)
    }

    func testHiddenChargeEndingLowerIsFencedByGap() {
        // Drains 0.55→0.50, charges to full overnight with no wake, and is
        // back DOWN at 0.45 five hours later. Level never increased, so only
        // the gap fence can stop a bogus 1%/hr fit at high confidence.
        let samples = [
            sample(0, 0.55), sample(30, 0.50),
            sample(330, 0.45),
        ]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(331 * 60), priorRatePerHour: 0.08)
        XCTAssertNotEqual(estimate.confidence, .high)
        // The 0.55→0.50 segment (10%/hr) is history; blend must sit well
        // above the polluted 0.018/hr a spanning fit would produce.
        XCTAssertGreaterThan(estimate.ratePerHour, 0.06)
    }

    // MARK: Cold start

    func testNoSamplesUsesPrior() {
        let estimate = DrainModel.estimate(samples: [], now: t0, priorRatePerHour: 0.07)
        XCTAssertEqual(estimate.ratePerHour, 0.07)
        XCTAssertEqual(estimate.confidence, .low)
        XCTAssertNil(estimate.deathDate)
    }

    func testSingleSampleUsesPriorButProducesDeathDate() {
        let estimate = DrainModel.estimate(samples: [sample(0, 0.20)], now: t0.addingTimeInterval(60), priorRatePerHour: 0.10)
        XCTAssertEqual(estimate.confidence, .low)
        XCTAssertNotNil(estimate.deathDate)
        // 20% at 10%/hr → ~2h.
        XCTAssertEqual(estimate.deathDate!.timeIntervalSince(t0), 2 * 3600, accuracy: 10 * 60)
    }

    // MARK: Historical blending

    func testHistoricalSegmentsRaiseConfidenceWithoutRecentData() {
        // A completed past discharge segment, then a gap, then one fresh sample.
        let samples = [
            sample(-600, 0.80), sample(-540, 0.70), sample(-480, 0.60),  // past: 10%/hr
            sample(-470, 0.90, charging: true),
            sample(0, 0.30),  // current session: single sample, no rate yet
        ]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(60), priorRatePerHour: 0.06)
        XCTAssertEqual(estimate.confidence, .medium)
        // Blend of historical 10%/hr and prior 6%/hr — should sit between.
        XCTAssertGreaterThan(estimate.ratePerHour, 0.06)
        XCTAssertLessThan(estimate.ratePerHour, 0.10)
    }

    func testStaleCompleteSegmentStillCountsAsHistory() {
        // A clean 10%/hr discharge recorded last night; user checks at noon.
        // Nothing is inside the 6h recent window, but the curve must not be
        // thrown away in favor of the bare prior.
        let samples = [
            sample(0, 0.80), sample(60, 0.70), sample(120, 0.60), sample(180, 0.50),
        ]
        let now = t0.addingTimeInterval(13 * 3600)
        let estimate = DrainModel.estimate(samples: samples, now: now, priorRatePerHour: 0.05)
        XCTAssertEqual(estimate.confidence, .medium)
        XCTAssertEqual(estimate.ratePerHour, 0.6 * 0.10 + 0.4 * 0.05, accuracy: 0.01)
    }

    func testSingleTransitionNeverGivesHighConfidence() {
        // One observed step can be off by ~2x from quantization phase alone.
        let samples = [sample(0, 0.40), sample(30, 0.35)]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(1800))
        XCTAssertEqual(estimate.confidence, .medium)
    }

    func testAdversariallyPhasedQuantizationStaysAccurate() {
        // True 10%/hr with steps landing between samples (steps at ~27 and
        // ~57 min); 10-min sampling. Transition-to-transition fit must stay
        // close despite the phase offset.
        let samples = [
            sample(0, 0.40), sample(10, 0.40), sample(20, 0.40),
            sample(30, 0.35), sample(40, 0.35), sample(50, 0.35),
            sample(60, 0.30),
        ]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(3600))
        XCTAssertEqual(estimate.ratePerHour, 0.10, accuracy: 0.02)
        XCTAssertEqual(estimate.confidence, .high)
    }

    // MARK: Robustness

    func testClockGoingBackwardsIsIgnored() {
        let samples = [
            sample(0, 0.50),
            BatterySample(timestamp: t0.addingTimeInterval(-3600), level: 0.90, isCharging: false),  // clock jumped back
            sample(60, 0.40),
        ]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(3600))
        XCTAssertEqual(estimate.ratePerHour, 0.10, accuracy: 0.03)
    }

    func testFutureTimestampIsNotAPoisonPill() {
        // One far-future sample must not out-order and erase every real
        // sample after it, nor become the estimate's anchor.
        let samples = [
            sample(0, 0.50),
            BatterySample(timestamp: t0.addingTimeInterval(365 * 24 * 3600), level: 0.90, isCharging: false),
            sample(30, 0.45), sample(60, 0.40),
        ]
        let now = t0.addingTimeInterval(3600)
        let estimate = DrainModel.estimate(samples: samples, now: now)
        XCTAssertEqual(estimate.ratePerHour, 0.10, accuracy: 0.03)
        XCTAssertEqual(estimate.latestSampleDate, t0.addingTimeInterval(3600))
        // Death within hours, not next year.
        XCTAssertLessThan(estimate.deathDate!.timeIntervalSince(now), 12 * 3600)
    }

    func testStaleChargingSampleDoesNotReportChargingForever() {
        // Last read was "charging" 24h ago. We can't still claim charging;
        // fall back to a low-confidence discharge guess from that level.
        let samples = [sample(0, 0.30), sample(10, 0.55, charging: true)]
        let now = t0.addingTimeInterval(24 * 3600)
        let estimate = DrainModel.estimate(samples: samples, now: now)
        XCTAssertFalse(estimate.isCharging)
        XCTAssertEqual(estimate.confidence, .low)
        XCTAssertNotNil(estimate.deathDate)
    }

    func testThresholdCrossingDate() {
        let estimate = Estimate(
            deathDate: t0.addingTimeInterval(4 * 3600), ratePerHour: 0.10,
            confidence: .high, isCharging: false, level: 0.40, latestSampleDate: t0
        )
        // 40% → 20% at 10%/hr = 2 hours from the anchor sample.
        let crossing = estimate.date(whenLevelReaches: 0.20)
        XCTAssertEqual(crossing!.timeIntervalSince(t0), 2 * 3600, accuracy: 60)
        XCTAssertNil(estimate.date(whenLevelReaches: 0.50))  // already below
    }

    func testAbsurdRateRejected() {
        // 50% drop in 15 minutes = 200%/hr — sensor glitch, not reality.
        let samples = [sample(0, 0.90), sample(15, 0.40)]
        let estimate = DrainModel.estimate(samples: samples, now: t0.addingTimeInterval(900), priorRatePerHour: 0.08)
        XCTAssertEqual(estimate.ratePerHour, 0.08, accuracy: 0.001)
    }

    func testDeathDateNeverInThePast() {
        // Stale samples: last read hours ago at 5% — raw math would put death in the past.
        let samples = [sample(0, 0.10), sample(30, 0.05)]
        let now = t0.addingTimeInterval(12 * 3600)
        let estimate = DrainModel.estimate(samples: samples, now: now)
        if let death = estimate.deathDate {
            XCTAssertGreaterThanOrEqual(death, now)
        }
    }
}
