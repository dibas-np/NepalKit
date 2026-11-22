// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The dataset ends at 2084 BS (2028-04-12). Past that there is no Bikram
/// Sambat answer, but the Gregorian date, weekday and clocks must keep working.
@MainActor
struct DatasetBoundaryTests {
    private let lastSupportedAD = GregorianDate(year: 2028, month: 4, day: 12)
    private let firstUnsupportedAD = GregorianDate(year: 2028, month: 4, day: 13)

    private func clock(_ date: GregorianDate) throws -> ClockModel {
        // Midday NPT, comfortably inside the civil day.
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        return ClockModel(
            now: try TestDates.utc(date.year, date.month, date.day, 6, 0),
            localTimeZone: zone,
            refreshes: false
        )
    }

    private func menuBar(_ date: GregorianDate) throws -> MenuBarModel {
        MenuBarModel(now: try TestDates.utc(date.year, date.month, date.day, 6, 0), refreshes: false, schedulesMidnightFire: false)
    }

    // MARK: - The supported-range edge

    @Test func lastSupportedDateStillConverts() throws {
        let model = try clock(lastSupportedAD)
        #expect(model.todayBSDate() == BikramSambatDate(year: 2084, month: 12, day: 30))
    }

    @Test func lastSupportedDateShowsABikramSambatDate() throws {
        let model = try menuBar(lastSupportedAD)
        let title = model.title(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))
        #expect(title != Strings.menuBarBeyondRange)
        // Menu-bar form is short: day + month, no year.
        #expect(title == "30 Chaitra")
    }

    // MARK: - Past the boundary

    @Test func firstUnsupportedDateHasNoBikramSambatAnswer() throws {
        #expect(try clock(firstUnsupportedAD).todayBSDate() == nil)
    }

    @Test func menuBarShowsBoundaryMarkerNotABareDash() throws {
        let title = try menuBar(firstUnsupportedAD)
            .title(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))
        #expect(title == Strings.menuBarBeyondRange)
        // A bare em dash reads as a bug or a loading failure rather than a data limit.
        #expect(title != "—")
    }

    @Test func gregorianAndClocksSurviveTheBoundary() throws {
        let model = try clock(firstUnsupportedAD)
        let ad = try #require(model.todayADDate())
        #expect(ad.formatted(digits: DisplaySettings(digits: .latin, monthNames: .transliterated).digits) == "13 April 2028")
        #expect(model.nptTimeString(digits: .latin) == "11:45:00")
    }

    @Test func weekdaySurvivesTheBoundary() throws {
        // 13 April 2028 is a Thursday. The weekday belongs to the civil day, so
        // it must not depend on a Bikram Sambat conversion succeeding.
        let model = try clock(firstUnsupportedAD)
        #expect(model.weekdayString(style: .transliterated) == "Thursday")
        #expect(model.weekdayString(style: .nepali) == "बिही")
    }

    @Test func weekdayIsUnchangedAcrossTheBoundary() throws {
        #expect(try clock(firstUnsupportedAD).weekdayString(style: .transliterated) == "Thursday")
        #expect(try clock(lastSupportedAD).weekdayString(style: .transliterated) == "Wednesday")
    }

    // MARK: - The notice names the boundary

    @Test func boundaryNoticeNamesTheLastSupportedYearInBothScripts() {
        let year = CalendarDataset.v2.supportedRange.upperBound
        #expect(year == 2084)
        #expect(Strings.supportedThrough(year, digits: .latin) == "Supported through 2084 BS")
        #expect(Strings.supportedThrough(year, digits: .devanagari) == "Supported through २०८४ BS")
    }

    @Test func boundaryNoticeUsesGlossaryLanguage() {
        // docs/glossary.md avoids "BS date" as prose for Bikram Sambat.
        #expect(Strings.bsDateUnavailable == "Bikram Sambat date unavailable")
        #expect(!Strings.bsDateUnavailable.contains("BS date"))
    }
}
