// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The supported range is 1918-04-13 through 2028-04-12 Gregorian.
struct ResolvedDayTests {
    private let dataset = CalendarDataset.v2

    // MARK: Supported days

    @Test func supportedDayCarriesBothIdentitiesAndOneWeekday() throws {
        // 27 Sep 2026 is 11 Ashoj 2083, a Sunday.
        let day = try ResolvedDay(GregorianDate(year: 2026, month: 9, day: 27), in: dataset)

        #expect(day.gregorian == GregorianDate(year: 2026, month: 9, day: 27))
        #expect(day.weekday == 1)
        #expect(day.bikramSambat == .supported(BikramSambatDate(year: 2083, month: 6, day: 11)))
    }

    @Test func firstSupportedDayIsSupported() throws {
        // 1 Baisakh 1975 is 13 April 1918, a Saturday.
        let day = try ResolvedDay(GregorianDate(year: 1918, month: 4, day: 13), in: dataset)

        #expect(day.weekday == 7)
        #expect(day.bikramSambat == .supported(BikramSambatDate(year: 1975, month: 1, day: 1)))
    }

    @Test func lastSupportedDayIsSupported() throws {
        // 30 Chaitra 2084 is 12 April 2028, a Wednesday.
        let day = try ResolvedDay(GregorianDate(year: 2028, month: 4, day: 12), in: dataset)

        #expect(day.weekday == 4)
        #expect(day.bikramSambat == .supported(BikramSambatDate(year: 2084, month: 12, day: 30)))
    }

    // MARK: Range boundaries are normal results

    @Test func dayBeforeMinimumIsABeforeBoundary() throws {
        let day = try ResolvedDay(GregorianDate(year: 1918, month: 4, day: 12), in: dataset)

        #expect(day.weekday == 6)
        #expect(day.bikramSambat == .beforeSupportedRange)
    }

    @Test func dayAfterMaximumIsAnAfterBoundary() throws {
        // 13 April 2028 is a Thursday.
        let day = try ResolvedDay(GregorianDate(year: 2028, month: 4, day: 13), in: dataset)

        #expect(day.weekday == 5)
        #expect(day.bikramSambat == .afterSupportedRange)
    }

    @Test func gregorianProgressionContinuesPastTheMaximum() throws {
        let day = try ResolvedDay(GregorianDate(year: 2028, month: 4, day: 14), in: dataset)

        #expect(day.weekday == 6)
        #expect(day.bikramSambat == .afterSupportedRange)
    }

    @Test func gregorianProgressionContinuesBeforeTheMinimum() throws {
        // 11 April 1918 is a Thursday.
        let day = try ResolvedDay(GregorianDate(year: 1918, month: 4, day: 11), in: dataset)

        #expect(day.weekday == 5)
        #expect(day.bikramSambat == .beforeSupportedRange)
    }

    // MARK: Errors are distinct from boundaries

    @Test func invalidCivilDayIsAnErrorNotABoundary() {
        #expect(throws: DayResolutionError.invalidCivilDay(GregorianDate(year: 2026, month: 2, day: 30))) {
            try ResolvedDay(GregorianDate(year: 2026, month: 2, day: 30), in: dataset)
        }
        #expect(throws: DayResolutionError.invalidCivilDay(GregorianDate(year: 2026, month: 13, day: 1))) {
            try ResolvedDay(GregorianDate(year: 2026, month: 13, day: 1), in: dataset)
        }
        #expect(throws: DayResolutionError.invalidCivilDay(GregorianDate(year: 2026, month: 4, day: 31))) {
            try ResolvedDay(GregorianDate(year: 2026, month: 4, day: 31), in: dataset)
        }
    }

    @Test func brokenDatasetAssumptionIsAnErrorDistinctFromBoundaries() {
        let broken = CalendarDataset(
            version: "broken-test",
            years: [1975: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]],
            anchorBikramSambat: BikramSambatDate(year: 1975, month: 1, day: 1),
            anchorGregorian: GregorianDate(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1975
        )

        #expect(throws: DayResolutionError.datasetAssumptionFailure(GregorianDate(year: 2026, month: 9, day: 27))) {
            try ResolvedDay(GregorianDate(year: 2026, month: 9, day: 27), in: broken)
        }
    }

    @Test func endDerivationFailureIsDistinctFromTheBeforeBoundary() throws {
        // A zero-length last year derives a start but no end.
        let brokenEnd = CalendarDataset(
            version: "broken-end-test",
            years: [
                1975: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
                1976: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            ],
            anchorBikramSambat: BikramSambatDate(year: 1975, month: 1, day: 1),
            anchorGregorian: GregorianDate(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1976
        )

        let beforeDay = try ResolvedDay(GregorianDate(year: 1918, month: 4, day: 12), in: brokenEnd)
        #expect(beforeDay.bikramSambat == .beforeSupportedRange)

        #expect(throws: DayResolutionError.datasetAssumptionFailure(GregorianDate(year: 1919, month: 1, day: 1))) {
            try ResolvedDay(GregorianDate(year: 1919, month: 1, day: 1), in: brokenEnd)
        }
    }

    @Test(arguments: [0, -1])
    func corruptIntermediateRowIsAnErrorInsideDerivedBounds(monthLength: Int) throws {
        let validMonths = [Int](repeating: 30, count: 12)
        var corruptMonths = validMonths
        corruptMonths[5] = monthLength
        let anchor = GregorianDate(year: 2000, month: 1, day: 1)
        let broken = CalendarDataset(
            version: "corrupt-intermediate-test",
            years: [2000: validMonths, 2001: corruptMonths, 2002: validMonths],
            anchorBikramSambat: BikramSambatDate(year: 2000, month: 1, day: 1),
            anchorGregorian: anchor,
            supportedRange: 2000 ... 2002
        )
        let start = try #require(broken.gregorianStart)
        let end = try #require(broken.gregorianEnd)

        for offset in [400, 800] {
            let day = try #require(anchor.advanced(byDays: offset))
            #expect(day >= start && day <= end)
            #expect(throws: DayResolutionError.datasetAssumptionFailure(day)) {
                try ResolvedDay(day, in: broken)
            }
        }
        let before = try #require(start.advanced(byDays: -1))
        let after = try #require(end.advanced(byDays: 1))
        #expect(try ResolvedDay(before, in: broken).bikramSambat == .beforeSupportedRange)
        #expect(try ResolvedDay(after, in: broken).bikramSambat == .afterSupportedRange)
    }

    // MARK: The instant resolver

    @Test func instantResolverAnchorsToNepalTime() throws {
        // 18:30 UTC on 26 Sep is past NPT midnight: 11 Ashoj 2083.
        let day = try ResolvedDay(now: try UTCDateFixture.utc(2026, 9, 26, 18, 30), in: dataset)

        #expect(day.gregorian == GregorianDate(year: 2026, month: 9, day: 27))
        #expect(day.bikramSambat == .supported(BikramSambatDate(year: 2083, month: 6, day: 11)))
    }

    @Test func instantResolverStaysOnThePreviousDayBeforeMidnight() throws {
        // 18:14 UTC on 26 Sep is 23:59 NPT on the 26th.
        let day = try ResolvedDay(now: try UTCDateFixture.utc(2026, 9, 26, 18, 14), in: dataset)

        #expect(day.gregorian == GregorianDate(year: 2026, month: 9, day: 26))
        #expect(day.weekday == 7)
    }

    @Test func instantResolverAtExactMidnightFlipsTheDay() throws {
        // 18:15 UTC on 26 Sep is exactly 00:00 NPT on the 27th.
        let day = try ResolvedDay(now: try UTCDateFixture.utc(2026, 9, 26, 18, 15), in: dataset)

        #expect(day.gregorian == GregorianDate(year: 2026, month: 9, day: 27))
    }

    @Test func instantResolverFollowsTheDatasetPastItsMaximum() throws {
        let instant = try UTCDateFixture.utc(2028, 4, 13, 12, 0)
        let day = try ResolvedDay(now: instant, in: dataset)

        #expect(day.gregorian == GregorianDate(year: 2028, month: 4, day: 13))
        #expect(day.bikramSambat == .afterSupportedRange)
    }
}
