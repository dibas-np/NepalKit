import XCTest
@testable import NepalKitCore

final class InvalidDateTests: XCTestCase {
    func testInvalidBSDatesReturnNil() {
        let invalid = [
            BSDay(year: 2083, month: 0, day: 11), // no month 0
            BSDay(year: 2083, month: 13, day: 1), // no month 13
            BSDay(year: 2083, month: 6, day: 0), // no day 0
            BSDay(year: 2083, month: 7, day: 31), // Kartik 2083 has 30 days
            BSDay(year: 1969, month: 12, day: 30), // below supported range
            BSDay(year: 2085, month: 1, day: 1), // above supported range
        ]
        for bs in invalid {
            XCTAssertNil(bsToAD(bs, in: .v1), "\(bs) must not convert")
        }
    }

    func testInvalidADDatesReturnNil() {
        let invalid = [
            GADay(year: 2024, month: 2, day: 30), // Feb 30 never exists
            GADay(year: 2026, month: 13, day: 1), // no month 13
            GADay(year: 2026, month: 9, day: 0), // no day 0
            GADay(year: 1913, month: 4, day: 12), // below supported range
            GADay(year: 2028, month: 4, day: 13), // above supported range
        ]
        for ad in invalid {
            XCTAssertNil(adToBS(ad, in: .v1), "\(ad) must not convert")
        }
    }
}
