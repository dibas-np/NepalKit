import XCTest
@testable import NepalKitCore

final class ConversionTests: XCTestCase {
    func testBSToADKnownDate() {
        let converted = bsToAD(BSDay(year: 2083, month: 6, day: 11), in: .sample)

        XCTAssertEqual(converted, GADay(year: 2026, month: 9, day: 27))
    }

    func testADToBSKnownDate() {
        let converted = adToBS(GADay(year: 2026, month: 9, day: 27), in: .sample)

        XCTAssertEqual(converted, BSDay(year: 2083, month: 6, day: 11))
    }

    func testWeekdayOfKnownDateIsSunday() {
        // 27 September 2026 is a Sunday; weekday 1 is Sunday.
        XCTAssertEqual(weekday(of: BSDay(year: 2083, month: 6, day: 11), in: .sample), 1)
    }
}
