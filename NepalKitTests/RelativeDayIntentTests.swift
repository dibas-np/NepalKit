// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The parameterless tomorrow and yesterday answers: Today's Nepal Time civil
/// day, plus or minus one, in Bikram Sambat.
///
/// Date anchors come from ticket 04's oracle, as in `TodayIntentTests`:
/// 1 Baisakh 2082 is Monday 14 April 2025 (the dataset anchor), so the last
/// day of 2081, 31 Chaitra, is 13 April 2025; 15 Ashar 2082 is Sunday
/// 29 June 2025, and Ashar 2082 has 32 days, so 32 Ashar is 16 July 2025 and
/// 1 Shrawan is 17 July 2025.
struct RelativeDayIntentTests {
    private var dataset: CalendarDataset { AppData.dataset }

    private static let devanagariDigits: [Character] = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

    @Test("Tomorrow and yesterday flip at Nepal Time midnight, not UTC midnight")
    func relativeDaysAreAnchoredToNepalTime() throws {
        // 14 April NPT begins at 18:15 UTC on 13 April.
        let before = try TestDates.utc(2025, 4, 13, 18, 14)
        let after = try TestDates.utc(2025, 4, 13, 18, 15)

        let tomorrowBefore = try TomorrowInBikramSambatIntent.answer(now: before, in: dataset, monthNames: .transliterated)
        let tomorrowAfter = try TomorrowInBikramSambatIntent.answer(now: after, in: dataset, monthNames: .transliterated)
        #expect(tomorrowBefore.entity.bsDay == BSDay(year: 2082, month: 1, day: 1))
        #expect(tomorrowAfter.entity.bsDay == BSDay(year: 2082, month: 1, day: 2))

        let yesterdayBefore = try YesterdayInBikramSambatIntent.answer(now: before, in: dataset, monthNames: .transliterated)
        let yesterdayAfter = try YesterdayInBikramSambatIntent.answer(now: after, in: dataset, monthNames: .transliterated)
        #expect(yesterdayBefore.entity.bsDay == BSDay(year: 2081, month: 12, day: 30))
        #expect(yesterdayAfter.entity.bsDay == BSDay(year: 2081, month: 12, day: 31))
    }

    @Test("Tomorrow and yesterday cross the Bikram Sambat year end")
    func relativeDaysCrossYearEnd() throws {
        // Midday NPT on 13 April 2025 (31 Chaitra 2081) and 14 April 2025
        // (1 Baisakh 2082, the dataset anchor).
        let lastDayOf2081 = try TestDates.utc(2025, 4, 13, 6, 0)
        let firstDayOf2082 = try TestDates.utc(2025, 4, 14, 6, 0)

        #expect(try TomorrowInBikramSambatIntent.answer(now: lastDayOf2081, in: dataset).entity.bsDay
            == BSDay(year: 2082, month: 1, day: 1))
        #expect(try YesterdayInBikramSambatIntent.answer(now: firstDayOf2082, in: dataset).entity.bsDay
            == BSDay(year: 2081, month: 12, day: 31))
    }

    @Test("Tomorrow and yesterday cross a Bikram Sambat month end")
    func relativeDaysCrossMonthEnd() throws {
        #expect(dataset.monthLengths(for: 2082)?[2] == 32)
        // Midday NPT on 16 July 2025 (32 Ashar 2082) and 17 July 2025
        // (1 Shrawan 2082).
        let lastOfAshar = try TestDates.utc(2025, 7, 16, 6, 0)
        let firstOfShrawan = try TestDates.utc(2025, 7, 17, 6, 0)

        #expect(try TomorrowInBikramSambatIntent.answer(now: lastOfAshar, in: dataset).entity.bsDay
            == BSDay(year: 2082, month: 4, day: 1))
        #expect(try YesterdayInBikramSambatIntent.answer(now: firstOfShrawan, in: dataset).entity.bsDay
            == BSDay(year: 2082, month: 3, day: 32))
    }

    @Test("Tomorrow past the supported range speaks Today's range-boundary dialog")
    func tomorrowPastRangeUsesBoundaryDialog() throws {
        let end = try #require(dataset.gregorianEnd)
        // Midday NPT on the dataset's last Gregorian day: today and yesterday
        // still convert, tomorrow does not.
        let now = try TestDates.utc(end.year, end.month, end.day, 6, 0)
        let expected = String(localized: TodayInBikramSambatIntent.beyondRangeDialog(now: now, in: dataset))

        #expect(todayBS(now: now, in: dataset) != nil)
        #expect(try YesterdayInBikramSambatIntent.answer(now: now, in: dataset).entity.bsDay.year
            == dataset.supportedRange.upperBound)

        do {
            _ = try TomorrowInBikramSambatIntent.answer(now: now, in: dataset)
            Issue.record("tomorrow past the supported range should not convert")
        } catch let error as SiriIntentError {
            #expect(String(localized: error.dialog) == expected)
            #expect(expected.contains(String(dataset.supportedRange.upperBound)))
        }
    }

    @Test("Spoken answers use Latin digits even with Nepali month names")
    func spokenAnswersUseLatinDigits() throws {
        let now = try TestDates.utc(2025, 6, 29, 6, 0) // 15 Ashar 2082, Sunday
        for monthNames in [MonthNameStyle.nepali, .transliterated] {
            let tomorrow = String(localized: try TomorrowInBikramSambatIntent.answer(now: now, in: dataset, monthNames: monthNames).dialog)
            let yesterday = String(localized: try YesterdayInBikramSambatIntent.answer(now: now, in: dataset, monthNames: monthNames).dialog)

            #expect(!tomorrow.contains(where: Self.devanagariDigits.contains))
            #expect(!yesterday.contains(where: Self.devanagariDigits.contains))
            #expect(tomorrow.hasPrefix("Tomorrow is ") && tomorrow.contains("16") && tomorrow.contains("2082"))
            #expect(yesterday.hasPrefix("Yesterday was ") && yesterday.contains("14") && yesterday.contains("2082"))
        }

        let english = String(localized: try TomorrowInBikramSambatIntent.answer(now: now, in: dataset, monthNames: .transliterated).dialog)
        #expect(english.contains("Monday"))
    }

    @Test("Running the intents answers the days either side of the real today")
    func performAnswersFromTheRealClock() async throws {
        // perform() reads the stored time reference, so the oracle does too:
        // a developer who chose their own zone would otherwise see a day apart.
        let zone = SettingsStore().timeReference.timeZone
        let before = Date()
        let tomorrow = try await TomorrowInBikramSambatIntent().perform()
        let yesterday = try await YesterdayInBikramSambatIntent().perform()
        let after = Date()
        // Either clock read may straddle midnight, so accept both.
        let tomorrows = [before, after].map { RelativeDay.bsDay(offset: 1, now: $0, timeZone: zone, in: dataset) }
        let yesterdays = [before, after].map { RelativeDay.bsDay(offset: -1, now: $0, timeZone: zone, in: dataset) }
        #expect(tomorrows.contains(tomorrow.value?.bsDay))
        #expect(yesterdays.contains(yesterday.value?.bsDay))
    }

    @Test("Tomorrow into a provisional year carries the projection clause; an attested one does not")
    func provisionalYearClause() throws {
        // 30 Chaitra 2083 is 13 April 2027; tomorrow is 1 Baisakh 2084, a
        // provisional year. Today itself (2083) is attested.
        let lastDayOf2083 = try TestDates.utc(2027, 4, 13, 6, 0)
        let tomorrow = String(localized: try TomorrowInBikramSambatIntent.answer(now: lastDayOf2083, in: dataset, monthNames: .transliterated).dialog)
        #expect(tomorrow.contains("provisional projection"))
        let yesterday = String(localized: try YesterdayInBikramSambatIntent.answer(now: lastDayOf2083, in: dataset, monthNames: .transliterated).dialog)
        #expect(!yesterday.contains("provisional"))
    }
}
