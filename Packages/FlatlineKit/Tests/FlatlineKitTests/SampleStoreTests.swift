import XCTest
@testable import FlatlineKit

final class SampleStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("flatline-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAppendAndLoadRoundTrip() {
        let store = SampleStore(directory: dir)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.append(BatterySample(timestamp: t0, level: 0.50, isCharging: false))
        store.append(BatterySample(timestamp: t0.addingTimeInterval(600), level: 0.45, isCharging: false))

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.level, 0.45)
    }

    func testRapidDuplicateSkipped() {
        let store = SampleStore(directory: dir)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.append(BatterySample(timestamp: t0, level: 0.50, isCharging: false))
        store.append(BatterySample(timestamp: t0.addingTimeInterval(10), level: 0.50, isCharging: false))
        XCTAssertEqual(store.load().count, 1)
    }

    func testOldSamplesPruned() {
        let store = SampleStore(directory: dir)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.append(BatterySample(timestamp: t0, level: 0.90, isCharging: false))
        // 15 days later — the first sample is past maxAge.
        store.append(BatterySample(timestamp: t0.addingTimeInterval(15 * 24 * 3600), level: 0.50, isCharging: false))
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.level, 0.50)
    }

    func testEmptyStoreLoadsEmpty() {
        XCTAssertEqual(SampleStore(directory: dir).load(), [])
    }

    func testConcurrentAppendsFromManyThreadsAllLand() {
        // The app, widget, and intent can all wake and write at once.
        let store = SampleStore(directory: dir)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        DispatchQueue.concurrentPerform(iterations: 50) { i in
            // Distinct timestamps/levels so the dedupe can't legitimately skip any.
            store.append(BatterySample(
                timestamp: t0.addingTimeInterval(Double(i) * 120),
                level: Double(50 + (i % 2)) / 100.0,
                isCharging: false
            ))
        }
        XCTAssertEqual(store.load().count, 50)
    }

    func testFutureStampedAppendRejectedAndDoesNotWipeStore() {
        let store = SampleStore(directory: dir)
        let now = Date()
        store.append(BatterySample(timestamp: now.addingTimeInterval(-600), level: 0.50, isCharging: false))
        store.append(BatterySample(timestamp: now, level: 0.45, isCharging: false))
        // Clock-garbage sample a year ahead: must be rejected outright, and
        // must not shift the age-pruning cutoff to erase the real history.
        store.append(BatterySample(timestamp: now.addingTimeInterval(365 * 24 * 3600), level: 0.90, isCharging: false))
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.level, 0.45)
    }

    func testSampleCapEnforced() throws {
        // Seed the file over the cap directly, then one append must trim it.
        let t0 = Date().addingTimeInterval(-3600)
        let seeded = (0..<2100).map {
            BatterySample(timestamp: t0.addingTimeInterval(Double($0)), level: 0.50, isCharging: false)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(seeded).write(to: dir.appendingPathComponent("battery-samples.json"))

        let store = SampleStore(directory: dir)
        store.append(BatterySample(timestamp: Date(), level: 0.45, isCharging: false))
        XCTAssertEqual(store.load().count, SampleStore.maxSamples)
    }
}
