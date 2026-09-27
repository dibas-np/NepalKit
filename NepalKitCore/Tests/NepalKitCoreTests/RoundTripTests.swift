import XCTest
@testable import NepalKitCore

/// Exhaustive Q19 matrix: every date in the supported range, both directions.
/// BS-side enumeration uses only the public table (data oracle), never the
/// conversion logic under test; the AD side iterates with Foundation's calendar.
final class RoundTripTests: XCTestCase {
    private var utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func utcDate(from ad: GADay) -> Date {
        utcCalendar.date(from: DateComponents(year: ad.year, month: ad.month, day: ad.day))!
    }

    private func everyBSDay(in dataset: CalendarDataset) -> [BSDay] {
        var days: [BSDay] = []
        for year in dataset.supportedRange {
            guard let months = dataset.monthLengths(for: year) else { continue }
            for (offset, length) in months.enumerated() {
                for day in 1 ... length {
                    days.append(BSDay(year: year, month: offset + 1, day: day))
                }
            }
        }
        return days
    }

    func testExhaustiveRoundTripBStoADtoBS() {
        for bs in everyBSDay(in: .v1) {
            guard let ad = bsToAD(bs, in: .v1) else {
                XCTFail("No conversion for \(bs)")
                return
            }
            XCTAssertEqual(adToBS(ad, in: .v1), bs, "Round trip failed for \(bs)")
        }
    }

    func testExhaustiveRoundTripADtoBStoAD() {
        var date = utcDate(from: GADay(year: 1913, month: 4, day: 13))
        let end = utcDate(from: GADay(year: 2028, month: 4, day: 12))
        while date <= end {
            let parts = utcCalendar.dateComponents([.year, .month, .day], from: date)
            let ad = GADay(year: parts.year!, month: parts.month!, day: parts.day!)
            guard let bs = adToBS(ad, in: .v1) else {
                XCTFail("No conversion for \(ad)")
                return
            }
            XCTAssertEqual(bsToAD(bs, in: .v1), ad, "Round trip failed for \(ad)")
            date = utcCalendar.date(byAdding: .day, value: 1, to: date)!
        }
    }

    func testConsecutiveBSDaysAdvanceOneADDay() {
        var previous: Date?
        for bs in everyBSDay(in: .v1) {
            guard let ad = bsToAD(bs, in: .v1) else {
                XCTFail("No conversion for \(bs)")
                return
            }
            let date = utcDate(from: ad)
            if let previous {
                let gap = utcCalendar.dateComponents([.day], from: previous, to: date).day
                XCTAssertEqual(gap, 1, "Non-consecutive mapping at \(bs)")
                if gap != 1 { return }
            }
            previous = date
        }
    }

    func testLeapDays() {
        // Feb 29 2000 (Tuesday) — ashesh Falgun 2056 grid.
        XCTAssertEqual(adToBS(GADay(year: 2000, month: 2, day: 29), in: .v1), BSDay(year: 2056, month: 11, day: 17))
        XCTAssertEqual(weekday(of: BSDay(year: 2056, month: 11, day: 17), in: .v1), 3)
        // Feb 29 2024 (Thursday) — Hamro Patro Poush 2080 grid pins Poush 27
        // to Jan 12 (not Jan 11), giving Falgun 1 = Feb 13: Feb 29 = Falgun 17.
        // (Hamro's own Falgun cells mislabel it 16; header + Poush grid agree on 17.)
        XCTAssertEqual(adToBS(GADay(year: 2024, month: 2, day: 29), in: .v1), BSDay(year: 2080, month: 11, day: 17))
        XCTAssertEqual(weekday(of: BSDay(year: 2080, month: 11, day: 17), in: .v1), 5)
        // Feb 29 2028 (Tuesday) — Falgun 2084 spans Feb 13–Mar 13.
        XCTAssertEqual(adToBS(GADay(year: 2028, month: 2, day: 29), in: .v1), BSDay(year: 2084, month: 11, day: 17))
        XCTAssertEqual(weekday(of: BSDay(year: 2084, month: 11, day: 17), in: .v1), 3)
    }

    func testVariableLengthMonthExtremes() {
        // 32-day Ashar 2084 — Hamro Patro grid.
        XCTAssertEqual(bsToAD(BSDay(year: 2084, month: 3, day: 32), in: .v1), GADay(year: 2027, month: 7, day: 16))
        // 29-day Mangsir 1989 — ashesh grid.
        XCTAssertEqual(bsToAD(BSDay(year: 1989, month: 8, day: 29), in: .v1), GADay(year: 1932, month: 12, day: 14))
        // Day after each extreme still maps consecutively.
        XCTAssertEqual(bsToAD(BSDay(year: 2084, month: 4, day: 1), in: .v1), GADay(year: 2027, month: 7, day: 17))
        XCTAssertEqual(bsToAD(BSDay(year: 1989, month: 9, day: 1), in: .v1), GADay(year: 1932, month: 12, day: 15))
    }

    func testRangeMinimumBothDirections() {
        XCTAssertEqual(bsToAD(BSDay(year: 1970, month: 1, day: 1), in: .v1), GADay(year: 1913, month: 4, day: 13))
        XCTAssertEqual(adToBS(GADay(year: 1913, month: 4, day: 13), in: .v1), BSDay(year: 1970, month: 1, day: 1))
    }

    func testRangeMaximumBothDirections() {
        // Chaitra 2084 — rat32 grid.
        XCTAssertEqual(bsToAD(BSDay(year: 2084, month: 12, day: 30), in: .v1), GADay(year: 2028, month: 4, day: 12))
        XCTAssertEqual(adToBS(GADay(year: 2028, month: 4, day: 12), in: .v1), BSDay(year: 2084, month: 12, day: 30))
    }
}
