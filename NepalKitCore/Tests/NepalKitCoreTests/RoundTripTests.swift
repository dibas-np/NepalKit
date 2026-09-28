import Foundation
import Testing
@testable import NepalKitCore

/// Exhaustive Q19 matrix: every date in the supported range, both directions.
/// BS-side enumeration uses only the public table (data oracle), never the
/// conversion logic under test; the AD side iterates with Foundation's calendar.
struct RoundTripTests {
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static func utcDate(from ad: GADay) -> Date {
        utcCalendar.date(from: DateComponents(year: ad.year, month: ad.month, day: ad.day))!
    }

    static func everyBSDay() -> [BSDay] {
        var days: [BSDay] = []
        for year in CalendarDataset.v2.supportedRange {
            guard let months = CalendarDataset.v2.monthLengths(for: year) else { continue }
            for (offset, length) in months.enumerated() {
                for day in 1 ... length {
                    days.append(BSDay(year: year, month: offset + 1, day: day))
                }
            }
        }
        return days
    }

    @Test func exhaustiveRoundTripBStoADtoBS() {
        for bs in Self.everyBSDay() {
            guard let ad = bsToAD(bs, in: .v2) else {
                Issue.record("No conversion for \(bs)")
                return
            }
            #expect(adToBS(ad, in: .v2) == bs, "round trip failed for \(bs)")
        }
    }

    @Test func exhaustiveRoundTripADtoBStoAD() {
        var date = Self.utcDate(from: GADay(year: 1918, month: 4, day: 13))
        let end = Self.utcDate(from: GADay(year: 2028, month: 4, day: 12))
        while date <= end {
            let parts = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            let ad = GADay(year: parts.year!, month: parts.month!, day: parts.day!)
            guard let bs = adToBS(ad, in: .v2) else {
                Issue.record("No conversion for \(ad)")
                return
            }
            #expect(bsToAD(bs, in: .v2) == ad, "round trip failed for \(ad)")
            date = Self.utcCalendar.date(byAdding: .day, value: 1, to: date)!
        }
    }

    @Test func consecutiveBSDaysAdvanceOneADDay() {
        var previous: Date?
        for bs in Self.everyBSDay() {
            guard let ad = bsToAD(bs, in: .v2) else {
                Issue.record("No conversion for \(bs)")
                return
            }
            let date = Self.utcDate(from: ad)
            if let previous {
                let gap = Self.utcCalendar.dateComponents([.day], from: previous, to: date).day
                #expect(gap == 1, "non-consecutive mapping at \(bs)")
                if gap != 1 { return }
            }
            previous = date
        }
    }

    @Test func leapDays() {
        // Feb 29 2000 (Tuesday) — ashesh Falgun 2056 grid.
        #expect(adToBS(GADay(year: 2000, month: 2, day: 29), in: .v2) == BSDay(year: 2056, month: 11, day: 17))
        #expect(weekday(of: BSDay(year: 2056, month: 11, day: 17), in: .v2) == 3)
        // Feb 29 2024 (Thursday) — Hamro Patro Poush 2080 grid pins Poush 27
        // to Jan 12 (not Jan 11), giving Falgun 1 = Feb 13: Feb 29 = Falgun 17.
        // (Hamro's own Falgun cells mislabel it 16; header + Poush grid agree on 17.)
        #expect(adToBS(GADay(year: 2024, month: 2, day: 29), in: .v2) == BSDay(year: 2080, month: 11, day: 17))
        #expect(weekday(of: BSDay(year: 2080, month: 11, day: 17), in: .v2) == 5)
        // Feb 29 2028 (Tuesday) — Falgun 2084 spans Feb 13–Mar 13.
        #expect(adToBS(GADay(year: 2028, month: 2, day: 29), in: .v2) == BSDay(year: 2084, month: 11, day: 17))
        #expect(weekday(of: BSDay(year: 2084, month: 11, day: 17), in: .v2) == 3)
    }

    @Test func variableLengthMonthExtremes() {
        // 32-day Ashar 2084 — Hamro Patro grid.
        #expect(bsToAD(BSDay(year: 2084, month: 3, day: 32), in: .v2) == GADay(year: 2027, month: 7, day: 16))
        // 29-day Mangsir 1989 — ashesh grid.
        #expect(bsToAD(BSDay(year: 1989, month: 8, day: 29), in: .v2) == GADay(year: 1932, month: 12, day: 14))
        // Day after each extreme still maps consecutively.
        #expect(bsToAD(BSDay(year: 2084, month: 4, day: 1), in: .v2) == GADay(year: 2027, month: 7, day: 17))
        #expect(bsToAD(BSDay(year: 1989, month: 9, day: 1), in: .v2) == GADay(year: 1932, month: 12, day: 15))
    }

    @Test func rangeMinimumBothDirections() {
        // 1 Baisakh 1975 is 13 April 1918 Gregorian (independent anchor list).
        #expect(bsToAD(BSDay(year: 1975, month: 1, day: 1), in: .v2) == GADay(year: 1918, month: 4, day: 13))
        #expect(adToBS(GADay(year: 1918, month: 4, day: 13), in: .v2) == BSDay(year: 1975, month: 1, day: 1))
    }

    @Test func rangeMaximumBothDirections() {
        // Chaitra 2084 — rat32 grid.
        #expect(bsToAD(BSDay(year: 2084, month: 12, day: 30), in: .v2) == GADay(year: 2028, month: 4, day: 12))
        #expect(adToBS(GADay(year: 2028, month: 4, day: 12), in: .v2) == BSDay(year: 2084, month: 12, day: 30))
    }
}
