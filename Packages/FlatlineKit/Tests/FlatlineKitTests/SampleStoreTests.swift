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
}
