// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The resolved-day and display contracts, exercised inside a watchOS test
/// runner (hosted in the Watch app on the watchOS 26 Simulator). The host
/// suite owns the exhaustive coverage; these prove the same seams answer
/// identically under watchOS.
struct WatchResolvedDayTests {
    private let dataset = CalendarDataset.v2

    private let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func anchoredInstant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return try #require(utcGregorian.date(from: components))
    }

    @Test func watchOSResolvesTheAnchoredSupportedDay() throws {
        // 26 September 2026, 18:30 UTC = 11 Ashoj 2083 (the host TodayTests
        // anchor), a Sunday.
        let day = try resolvedDay(now: try anchoredInstant(2026, 9, 26, 18, 30), in: dataset)

        #expect(day.gregorian == GADay(year: 2026, month: 9, day: 27))
        #expect(day.weekday == 1)
        #expect(day.bikramSambat == .supported(BSDay(year: 2083, month: 6, day: 11)))
    }

    @Test func watchOSResolvesBothBoundariesWithGregorianProgression() throws {
        let afterMaximum = try resolvedDay(for: GADay(year: 2028, month: 4, day: 13), in: dataset)
        #expect(afterMaximum.bikramSambat == .afterSupportedRange)
        #expect(afterMaximum.weekday == 5)

        let beforeMinimum = try resolvedDay(for: GADay(year: 1918, month: 4, day: 12), in: dataset)
        #expect(beforeMinimum.bikramSambat == .beforeSupportedRange)
        #expect(beforeMinimum.weekday == 6)
    }

    @Test func watchOSRejectsInvalidCivilInputAsAnError() {
        #expect(throws: DayResolutionError.invalidCivilDay(GADay(year: 2026, month: 2, day: 30))) {
            try resolvedDay(for: GADay(year: 2026, month: 2, day: 30), in: dataset)
        }
    }

    @Test func watchOSRendersTheCanonicalDisplayAndSpeech() throws {
        let day = try resolvedDay(now: try anchoredInstant(2026, 9, 26, 18, 30), in: dataset)

        guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a supported display")
            return
        }

        #expect(components.weekdayName == "आइत")
        #expect(components.bikramSambatDay == "११")
        #expect(components.bikramSambatMonthName == "असोज")
        #expect(components.bikramSambatYear == "२०८३")
        #expect(components.spokenBikramSambat == "11 असोज 2083")
        #expect(components.spokenGregorian == "27 September 2026")
    }
}
