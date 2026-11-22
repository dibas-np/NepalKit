import Foundation
import Testing
import NepalKitCore

struct RoundTripTests {
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    static func utcDate(from ad: GregorianDate) throws -> Date {
        try #require(utcCalendar.date(from: DateComponents(year: ad.year, month: ad.month, day: ad.day)))
    }

    static func everyBSDay() -> [BikramSambatDate] {
        var days: [BikramSambatDate] = []
        for year in CalendarDataset.v2.supportedRange {
            guard let months = CalendarDataset.v2.monthLengths(for: year) else {
                Issue.record("No twelve-month table row for \(year); the round-trip sweep is not exhaustive")
                continue
            }
            for (offset, length) in months.enumerated() {
                for day in 1 ... length {
                    days.append(BikramSambatDate(year: year, month: offset + 1, day: day))
                }
            }
        }
        return days
    }

    @Test func exhaustiveRoundTripBStoADtoBS() {
        for bs in Self.everyBSDay() {
            guard let ad = GregorianDate(bs, in: .v2) else {
                Issue.record("No conversion for \(bs)")
                return
            }
            #expect(BikramSambatDate(ad, in: .v2) == bs, "round trip failed for \(bs)")
        }
    }

    @Test func exhaustiveRoundTripADtoBStoAD() throws {
        var date = try Self.utcDate(from: GregorianDate(year: 1918, month: 4, day: 13))
        let end = try Self.utcDate(from: GregorianDate(year: 2028, month: 4, day: 12))
        while date <= end {
            let parts = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            let year = try #require(parts.year)
            let month = try #require(parts.month)
            let day = try #require(parts.day)
            let ad = GregorianDate(year: year, month: month, day: day)
            guard let bs = BikramSambatDate(ad, in: .v2) else {
                Issue.record("No conversion for \(ad)")
                return
            }
            #expect(GregorianDate(bs, in: .v2) == ad, "round trip failed for \(ad)")
            date = try #require(Self.utcCalendar.date(byAdding: .day, value: 1, to: date))
        }
    }

    @Test func consecutiveBSDaysAdvanceOneADDay() throws {
        var previous: Date?
        for bs in Self.everyBSDay() {
            guard let ad = GregorianDate(bs, in: .v2) else {
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
        #expect(BikramSambatDate(GregorianDate(year: 2000, month: 2, day: 29), in: .v2) == BikramSambatDate(year: 2056, month: 11, day: 17))
        #expect(BikramSambatDate(year: 2056, month: 11, day: 17).weekday(in: .v2) == 3)
        #expect(BikramSambatDate(GregorianDate(year: 2024, month: 2, day: 29), in: .v2) == BikramSambatDate(year: 2080, month: 11, day: 17))
        #expect(BikramSambatDate(year: 2080, month: 11, day: 17).weekday(in: .v2) == 5)
        #expect(BikramSambatDate(GregorianDate(year: 2028, month: 2, day: 29), in: .v2) == BikramSambatDate(year: 2084, month: 11, day: 17))
        #expect(BikramSambatDate(year: 2084, month: 11, day: 17).weekday(in: .v2) == 3)
    }

    @Test func variableLengthMonthExtremes() {
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 2, day: 32), in: .v2) == GregorianDate(year: 2027, month: 6, day: 15))
        #expect(GregorianDate(BikramSambatDate(year: 1989, month: 8, day: 29), in: .v2) == GregorianDate(year: 1932, month: 12, day: 14))
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 3, day: 1), in: .v2) == GregorianDate(year: 2027, month: 6, day: 16))
        #expect(GregorianDate(BikramSambatDate(year: 1989, month: 9, day: 1), in: .v2) == GregorianDate(year: 1932, month: 12, day: 15))
    }

    @Test func rangeMinimumBothDirections() {
        #expect(GregorianDate(BikramSambatDate(year: 1975, month: 1, day: 1), in: .v2) == GregorianDate(year: 1918, month: 4, day: 13))
        #expect(BikramSambatDate(GregorianDate(year: 1918, month: 4, day: 13), in: .v2) == BikramSambatDate(year: 1975, month: 1, day: 1))
    }

    @Test func rangeMaximumBothDirections() {
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 12, day: 30), in: .v2) == GregorianDate(year: 2028, month: 4, day: 12))
        #expect(BikramSambatDate(GregorianDate(year: 2028, month: 4, day: 12), in: .v2) == BikramSambatDate(year: 2084, month: 12, day: 30))
    }
}
