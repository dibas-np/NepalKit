import XCTest
@testable import NepalKitCore

final class WeekdayNameTests: XCTestCase {
    func testNepaliWeekdayNames() {
        let expected = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
        for day in 1 ... 7 {
            XCTAssertEqual(weekdayName(for: day, style: .nepali), expected[day - 1])
        }
    }

    func testTransliteratedWeekdayNamesAreEnglish() {
        let expected = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        for day in 1 ... 7 {
            XCTAssertEqual(weekdayName(for: day, style: .transliterated), expected[day - 1])
        }
    }

    func testAllSevenDaysEndToEndThroughWeekday() {
        // 27 Sep – 3 Oct 2026 are Sunday–Saturday; Ashoj 11–17, 2083.
        for offset in 0 ... 6 {
            let bs = BSDay(year: 2083, month: 6, day: 11 + offset)
            XCTAssertEqual(weekday(of: bs, in: .v1), offset + 1, "weekday of \(bs)")
            XCTAssertEqual(weekdayName(for: offset + 1, style: .nepali), ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"][offset])
        }
    }

    func testOutOfRangeWeekdayReturnsNil() {
        XCTAssertNil(weekdayName(for: 0, style: .nepali))
        XCTAssertNil(weekdayName(for: 8, style: .transliterated))
    }
}
