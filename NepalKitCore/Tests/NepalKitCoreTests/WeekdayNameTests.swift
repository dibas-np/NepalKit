import XCTest
@testable import NepalKitCore

final class WeekdayNameTests: XCTestCase {
    func testNepaliWeekdayNames() {
        XCTAssertEqual(
            (1 ... 7).map { weekdayName(for: $0, style: .nepali) },
            ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
        )
    }

    func testTransliteratedWeekdayNamesAreEnglish() {
        XCTAssertEqual(
            (1 ... 7).map { weekdayName(for: $0, style: .transliterated) },
            ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        )
    }

    func testKnownDateWeekdayNameEndToEnd() {
        // 27 September 2026 is a Sunday; Ashoj 2083 uses full Nepali names.
        let bs = BSDay(year: 2083, month: 6, day: 11)
        XCTAssertEqual(weekday(of: bs, in: .v1), 1)
        XCTAssertEqual(weekdayName(for: 1, style: .nepali), "आइत")
        XCTAssertEqual(weekdayName(for: 1, style: .transliterated), "Sunday")
    }
}
