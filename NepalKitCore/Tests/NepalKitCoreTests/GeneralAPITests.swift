// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

struct GeneralAPITests {
    private let newYear = BikramSambatDate(year: 2083, month: 1, day: 1)

    @Test func conversionsDefaultToTheBundledDataset() {
        #expect(CalendarDataset.bundled.version == CalendarDataset.v2.version)
        #expect(GregorianDate(newYear) == GregorianDate(newYear, in: .v2))
        #expect(BikramSambatDate(GregorianDate(year: 2026, month: 4, day: 14)) == newYear)
        #expect(newYear.weekday() == newYear.weekday(in: .v2))
    }

    @Test func datesOrderByYearThenMonthThenDay() {
        let dates = [
            BikramSambatDate(year: 2083, month: 2, day: 1),
            BikramSambatDate(year: 2082, month: 12, day: 30),
            BikramSambatDate(year: 2083, month: 1, day: 32),
        ]
        #expect(dates.sorted() == [dates[1], dates[2], dates[0]])
        #expect(GregorianDate(year: 2026, month: 1, day: 31) < GregorianDate(year: 2026, month: 2, day: 1))
        #expect(GregorianDate(year: 2025, month: 12, day: 31) < GregorianDate(year: 2026, month: 1, day: 1))
    }

    @Test func datesAndSettingsRoundTripThroughJSON() throws {
        let settings = DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        let gregorian = GregorianDate(year: 2026, month: 4, day: 14)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        #expect(try decoder.decode(BikramSambatDate.self, from: encoder.encode(newYear)) == newYear)
        #expect(try decoder.decode(GregorianDate.self, from: encoder.encode(gregorian)) == gregorian)
        #expect(try decoder.decode(DisplaySettings.self, from: encoder.encode(settings)) == settings)
    }

    @Test func formatTimeDefaultsToTwentyFourHoursWithSecondsInNepalTime() throws {
        let evening = try UTCDateFixture.utc(2026, 9, 27, 17, 12, 7)
        #expect(DigitScript.latin.formatTime(evening) == "22:57:07")
        #expect(DigitScript.latin.formatTime(evening, twentyFourHour: false) == "10:57:07")
        #expect(DigitScript.devanagari.formatTime(evening, twentyFourHour: false, showsSeconds: false) == "१०:५७")
    }

    @Test func midnightAndNoonReadTwelveOnATwelveHourClock() throws {
        #expect(try DigitScript.latin.formatTime(UTCDateFixture.utc(2026, 9, 27, 18, 15), twentyFourHour: false, showsSeconds: false) == "12:00")
        #expect(try DigitScript.latin.formatTime(UTCDateFixture.utc(2026, 9, 27, 6, 15), twentyFourHour: false, showsSeconds: false) == "12:00")
        #expect(try DigitScript.latin.formatTime(UTCDateFixture.utc(2026, 9, 27, 18, 15), showsSeconds: false) == "00:00")
    }

    @Test func formattedCanDropTheYear() {
        let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
        #expect(newYear.formatted(latin) == "1 Baisakh 2083")
        #expect(newYear.formatted(latin, includesYear: false) == "1 Baisakh")
    }
}
