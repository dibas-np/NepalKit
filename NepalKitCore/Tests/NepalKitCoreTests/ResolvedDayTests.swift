// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The resolved-day contract: one Nepal Time civil day carries its Gregorian
/// identity, one weekday, and either a supported Bikram Sambat date or an
/// explicit range boundary. Gregorian progression continues outside the
/// supported range; invalid input and broken dataset assumptions are errors,
/// never boundaries.
///
/// Boundary dates reuse the pinned dataset facts (1918-04-13 through
/// 2028-04-12 Gregorian) and the weekday anchors `GregorianWeekdayTests`
/// already established; nothing here regenerates expectations through the
/// code under test.
struct ResolvedDayTests {
    private let dataset = CalendarDataset.v2

    // MARK: Supported days

    @Test func supportedDayCarriesBothIdentitiesAndOneWeekday() throws {
        // 26 Sep 2026, 18:30 UTC is already 27 Sep in Nepal Time: 11 Ashoj 2083,
        // a Sunday (GregorianWeekdayTests pins the weekday).
        let day = try resolvedDay(for: GADay(year: 2026, month: 9, day: 27), in: dataset)

        #expect(day.gregorian == GADay(year: 2026, month: 9, day: 27))
        #expect(day.weekday == 1)
        #expect(day.bikramSambat == .supported(BSDay(year: 2083, month: 6, day: 11)))
    }

    @Test func firstSupportedDayIsSupported() throws {
        // 1 Baisakh 1975 is 13 April 1918, a Saturday — the dataset's inclusive
        // Gregorian start, so the boundary day itself is supported.
        let day = try resolvedDay(for: GADay(year: 1918, month: 4, day: 13), in: dataset)

        #expect(day.weekday == 7)
        #expect(day.bikramSambat == .supported(BSDay(year: 1975, month: 1, day: 1)))
    }

    @Test func lastSupportedDayIsSupported() throws {
        // 30 Chaitra 2084 is 12 April 2028, a Wednesday — the dataset's
        // inclusive Gregorian end.
        let day = try resolvedDay(for: GADay(year: 2028, month: 4, day: 12), in: dataset)

        #expect(day.weekday == 4)
        #expect(day.bikramSambat == .supported(BSDay(year: 2084, month: 12, day: 30)))
    }

    // MARK: Range boundaries are normal results

    @Test func dayBeforeMinimumIsABeforeBoundary() throws {
        let day = try resolvedDay(for: GADay(year: 1918, month: 4, day: 12), in: dataset)

        #expect(day.weekday == 6)
        #expect(day.bikramSambat == .beforeSupportedRange)
    }

    @Test func dayAfterMaximumIsAnAfterBoundary() throws {
        // 13 April 2028 is a Thursday (GregorianWeekdayTests pins it).
        let day = try resolvedDay(for: GADay(year: 2028, month: 4, day: 13), in: dataset)

        #expect(day.weekday == 5)
        #expect(day.bikramSambat == .afterSupportedRange)
    }

    @Test func gregorianProgressionContinuesPastTheMaximum() throws {
        // The day after the boundary progresses independently: its weekday is
        // the next civil day's, and the boundary stays an expected result.
        let day = try resolvedDay(for: GADay(year: 2028, month: 4, day: 14), in: dataset)

        #expect(day.weekday == 6)
        #expect(day.bikramSambat == .afterSupportedRange)
    }

    @Test func gregorianProgressionContinuesBeforeTheMinimum() throws {
        // 11 April 1918 is a Thursday (Foundation numbers it 5).
        let day = try resolvedDay(for: GADay(year: 1918, month: 4, day: 11), in: dataset)

        #expect(day.weekday == 5)
        #expect(day.bikramSambat == .beforeSupportedRange)
    }

    // MARK: Errors are distinct from boundaries

    @Test func invalidCivilDayIsAnErrorNotABoundary() {
        // February 30 does not name a real day: it must fail as invalid input,
        // not normalize into a March boundary.
        #expect(throws: DayResolutionError.invalidCivilDay(GADay(year: 2026, month: 2, day: 30))) {
            try resolvedDay(for: GADay(year: 2026, month: 2, day: 30), in: dataset)
        }
        #expect(throws: DayResolutionError.invalidCivilDay(GADay(year: 2026, month: 13, day: 1))) {
            try resolvedDay(for: GADay(year: 2026, month: 13, day: 1), in: dataset)
        }
        #expect(throws: DayResolutionError.invalidCivilDay(GADay(year: 2026, month: 4, day: 31))) {
            try resolvedDay(for: GADay(year: 2026, month: 4, day: 31), in: dataset)
        }
    }

    @Test func brokenDatasetAssumptionIsAnErrorDistinctFromBoundaries() {
        // A table whose supported-range year has zero-length months cannot
        // derive its Gregorian bounds: every resolution must fail loudly as a
        // dataset assumption failure rather than report a boundary.
        let broken = CalendarDataset(
            version: "broken-test",
            years: [1975: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]],
            anchorBS: BSDay(year: 1975, month: 1, day: 1),
            anchorAD: GADay(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1975
        )

        #expect(throws: DayResolutionError.datasetAssumptionFailure(GADay(year: 2026, month: 9, day: 27))) {
            try resolvedDay(for: GADay(year: 2026, month: 9, day: 27), in: broken)
        }
    }

    @Test func endDerivationFailureIsDistinctFromTheBeforeBoundary() throws {
        // A table whose last year is zero-length derives a start but no end:
        // days before the start still report the before boundary; days the
        // table should cover fail as a dataset assumption.
        let brokenEnd = CalendarDataset(
            version: "broken-end-test",
            years: [
                1975: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
                1976: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            ],
            anchorBS: BSDay(year: 1975, month: 1, day: 1),
            anchorAD: GADay(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1976
        )

        let beforeDay = try resolvedDay(for: GADay(year: 1918, month: 4, day: 12), in: brokenEnd)
        #expect(beforeDay.bikramSambat == .beforeSupportedRange)

        #expect(throws: DayResolutionError.datasetAssumptionFailure(GADay(year: 1919, month: 1, day: 1))) {
            try resolvedDay(for: GADay(year: 1919, month: 1, day: 1), in: brokenEnd)
        }
    }

    // MARK: The instant resolver

    @Test func instantResolverAnchorsToNepalTime() throws {
        // 18:30 UTC on 26 Sep is past NPT midnight: 11 Ashoj 2083.
        let day = try resolvedDay(now: try UTCDateFixture.utc(2026, 9, 26, 18, 30), in: dataset)

        #expect(day.gregorian == GADay(year: 2026, month: 9, day: 27))
        #expect(day.bikramSambat == .supported(BSDay(year: 2083, month: 6, day: 11)))
    }

    @Test func instantResolverStaysOnThePreviousDayBeforeMidnight() throws {
        // 18:14 UTC on 26 Sep is 23:59 NPT on the 26th.
        let day = try resolvedDay(now: try UTCDateFixture.utc(2026, 9, 26, 18, 14), in: dataset)

        #expect(day.gregorian == GADay(year: 2026, month: 9, day: 26))
        #expect(day.weekday == 7)
    }

    @Test func instantResolverAtExactMidnightFlipsTheDay() throws {
        // 18:15 UTC on 26 Sep is exactly 00:00 NPT on the 27th.
        let day = try resolvedDay(now: try UTCDateFixture.utc(2026, 9, 26, 18, 15), in: dataset)

        #expect(day.gregorian == GADay(year: 2026, month: 9, day: 27))
    }

    @Test func instantResolverFollowsTheDatasetPastItsMaximum() throws {
        // An instant past the Gregorian end resolves its NPT day as an
        // after-boundary, with the Gregorian day still carried.
        let instant = try UTCDateFixture.utc(2028, 4, 13, 12, 0)
        let day = try resolvedDay(now: instant, in: dataset)

        #expect(day.gregorian == GADay(year: 2028, month: 4, day: 13))
        #expect(day.bikramSambat == .afterSupportedRange)
    }
}
