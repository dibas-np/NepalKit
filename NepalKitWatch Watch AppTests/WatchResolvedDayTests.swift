// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import NepalKitWatchSupport

struct WatchResolvedDayTests {
    private let dataset = CalendarDataset.v2

    @Test func watchOSResolvesTheAnchoredSupportedDay() throws {
        let day = try ResolvedDay(now: try UTCWatchFixture.utc(2026, 9, 26, 18, 30), in: dataset)

        #expect(day.gregorian == GregorianDate(year: 2026, month: 9, day: 27))
        #expect(day.weekday == 1)
        #expect(day.bikramSambat == .supported(BikramSambatDate(year: 2083, month: 6, day: 11)))
    }

    @Test func watchOSResolvesBothBoundariesWithGregorianProgression() throws {
        let afterMaximum = try ResolvedDay(GregorianDate(year: 2028, month: 4, day: 13), in: dataset)
        #expect(afterMaximum.bikramSambat == .afterSupportedRange)
        #expect(afterMaximum.weekday == 5)

        let beforeMinimum = try ResolvedDay(GregorianDate(year: 1918, month: 4, day: 12), in: dataset)
        #expect(beforeMinimum.bikramSambat == .beforeSupportedRange)
        #expect(beforeMinimum.weekday == 6)
    }

    @Test func watchOSRejectsInvalidCivilInputAsAnError() {
        #expect(throws: DayResolutionError.invalidCivilDay(GregorianDate(year: 2026, month: 2, day: 30))) {
            try ResolvedDay(GregorianDate(year: 2026, month: 2, day: 30), in: dataset)
        }
    }

    @Test func watchOSRendersTheCanonicalDisplayAndSpeech() throws {
        let day = try ResolvedDay(now: try UTCWatchFixture.utc(2026, 9, 26, 18, 30), in: dataset)

        guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a supported display")
            return
        }

        #expect(components.weekdayName == "आइत")
        #expect(components.bikramSambatDay == "११")
        #expect(components.bikramSambatMonthName == "असोज")
        #expect(components.bikramSambatYear == "२०८३")
        #expect(components.spokenBikramSambat == "11 Ashoj 2083")
        #expect(components.spokenGregorian == "27 September 2026")
    }
}
