import Foundation
import Testing
import NepalKitCore

/// Exhaustive Q19 matrix: every date in the supported range, both directions.
/// BS-side enumeration uses only the public table (data oracle), never the
/// conversion logic under test; the AD side iterates with Foundation's calendar.
struct RoundTripTests {
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    static func utcDate(from ad: GADay) throws -> Date {
        try #require(utcCalendar.date(from: DateComponents(year: ad.year, month: ad.month, day: ad.day)))
    }

    static func everyBSDay() -> [BSDay] {
        var days: [BSDay] = []
        for year in CalendarDataset.v2.supportedRange {
            // A missing row is the defect these tests exist to catch, so it is
            // recorded rather than skipped past. A bare `continue` here made the
            // suite green over a smaller sweep, which is the rule
            // CODING_STANDARDS.md §Changing a supported-range boundary states and
            // GregorianWeekdayTests already follows.
            guard let months = CalendarDataset.v2.monthLengths(for: year) else {
                Issue.record("No twelve-month table row for \(year); the round-trip sweep is not exhaustive")
                continue
            }
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

    @Test func exhaustiveRoundTripADtoBStoAD() throws {
        var date = try Self.utcDate(from: GADay(year: 1918, month: 4, day: 13))
        let end = try Self.utcDate(from: GADay(year: 2028, month: 4, day: 12))
        while date <= end {
            let parts = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            let year = try #require(parts.year)
            let month = try #require(parts.month)
            let day = try #require(parts.day)
            let ad = GADay(year: year, month: month, day: day)
            guard let bs = adToBS(ad, in: .v2) else {
                Issue.record("No conversion for \(ad)")
                return
            }
            #expect(bsToAD(bs, in: .v2) == ad, "round trip failed for \(ad)")
            date = try #require(Self.utcCalendar.date(byAdding: .day, value: 1, to: date))
        }
    }

    @Test func consecutiveBSDaysAdvanceOneADDay() throws {
        var previous: Date?
        for bs in Self.everyBSDay() {
            guard let ad = bsToAD(bs, in: .v2) else {
                Issue.record("No conversion for \(bs)")
                return
            }
            let date = try Self.utcDate(from: ad)
            if let previous {
                let gap = Self.utcCalendar.dateComponents([.day], from: previous, to: date).day
                #expect(gap == 1, "non-consecutive mapping at \(bs)")
                if gap != 1 { return }
            }
            previous = date
        }
    }

    /// That the enumeration above is the whole table, and not a quiet subset of
    /// it.
    ///
    /// Every other test in this file passes just as happily over a shorter
    /// `days` array: a year the enumeration skipped, or a month it dropped, would
    /// shrink the 40,178-day sweep and leave three green tests behind it. So the
    /// claim the round trips cannot make about themselves is asserted here.
    ///
    /// The count is compared against the table's own month lengths, summed
    /// separately, rather than against a literal — a literal would need editing
    /// every time the range is extended, and a test that has to be updated when
    /// the data moves is one more thing that can be forgotten. `!days.isEmpty`
    /// would not do either: a sweep missing every day after the first year is
    /// still non-empty, and still green.
    ///
    /// A month length that is present but wrong is not caught here, and does not
    /// need to be: the phantom day it invents has no conversion, so
    /// `exhaustiveRoundTripBStoADtoBS` records it, and a short one loses a day
    /// that `consecutiveBSDaysAdvanceOneADDay` reports as a gap.
    @Test func everyBSDayEnumeratesTheWholeTable() {
        let days = Self.everyBSDay()
        let dataset = CalendarDataset.v2
        let tableTotal = dataset.supportedRange.reduce(0) { total, year in
            total + (dataset.monthLengths(for: year)?.reduce(0, +) ?? 0)
        }

        #expect(
            Set(days.map(\.year)) == Set(dataset.supportedRange),
            "a supported year contributed no days to the sweep"
        )
        #expect(days.count == tableTotal, "the sweep covers \(days.count) days, not the table's \(tableTotal)")
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
        // Provisional 2084 contract: Feb 29 2028 is Tuesday; not an official anchor.
        #expect(adToBS(GADay(year: 2028, month: 2, day: 29), in: .v2) == BSDay(year: 2084, month: 11, day: 17))
        #expect(weekday(of: BSDay(year: 2084, month: 11, day: 17), in: .v2) == 3)
    }

    @Test func variableLengthMonthExtremes() {
        // User-approved projection has 32-day Jestha, ending 15 June 2027.
        #expect(bsToAD(BSDay(year: 2084, month: 2, day: 32), in: .v2) == GADay(year: 2027, month: 6, day: 15))
        // 29-day Mangsir 1989 — ashesh grid.
        #expect(bsToAD(BSDay(year: 1989, month: 8, day: 29), in: .v2) == GADay(year: 1932, month: 12, day: 14))
        // Day after each extreme still maps consecutively.
        #expect(bsToAD(BSDay(year: 2084, month: 3, day: 1), in: .v2) == GADay(year: 2027, month: 6, day: 16))
        #expect(bsToAD(BSDay(year: 1989, month: 9, day: 1), in: .v2) == GADay(year: 1932, month: 12, day: 15))
    }

    @Test func rangeMinimumBothDirections() {
        // 1 Baisakh 1975 is 13 April 1918 Gregorian (independent anchor list).
        #expect(bsToAD(BSDay(year: 1975, month: 1, day: 1), in: .v2) == GADay(year: 1918, month: 4, day: 13))
        #expect(adToBS(GADay(year: 1918, month: 4, day: 13), in: .v2) == BSDay(year: 1975, month: 1, day: 1))
    }

    @Test func rangeMaximumBothDirections() {
        // Provisional 2084 contract; unchanged endpoint, not official attestation.
        #expect(bsToAD(BSDay(year: 2084, month: 12, day: 30), in: .v2) == GADay(year: 2028, month: 4, day: 12))
        #expect(adToBS(GADay(year: 2028, month: 4, day: 12), in: .v2) == BSDay(year: 2084, month: 12, day: 30))
    }
}
