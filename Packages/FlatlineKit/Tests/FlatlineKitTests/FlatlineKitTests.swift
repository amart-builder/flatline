import XCTest
@testable import FlatlineKit

final class FlatlineKitTests: XCTestCase {
    func testBatterySampleRoundTrip() throws {
        let sample = BatterySample(timestamp: Date(timeIntervalSince1970: 1000), level: 0.20, isCharging: false)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(BatterySample.self, from: data)
        XCTAssertEqual(sample, decoded)
    }
}
