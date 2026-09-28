// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The bundled dataset ends at 2084 BS, which is 2028-04-12 Gregorian. Past
/// that the app has no Bikram Sambat answer, but the Gregorian date, its
/// weekday, and the clocks are all still perfectly well defined — so they must
/// keep working. These tests pin that boundary from both sides.
@MainActor
struct DatasetBoundaryTests {
    private let lastSupportedAD = GADay(year: 2028, month: 4, day: 12)
    private let firstUnsupportedAD = GADay(year: 2028, month: 4, day: 13)

    private func clock(_ date: GADay) -> ClockModel {
        // Midday NPT, comfortably inside the civil day.
        ClockModel(
            now: TestDates.utc(date.year, date.month, date.day, 6, 0),
            localTimeZone: TimeZone(identifier: "America/New_York")!,
            refreshInterval: 3600
        )
    }

    private func menuBar(_ date: GADay) -> MenuBarModel {
        MenuBarModel(now: TestDates.utc(date.year, date.month, date.day, 6, 0), refreshInterval: 3600)
    }

    // MARK: - The supported-range edge

    @Test func lastSupportedDateStillConverts() {
        let model = clock(lastSupportedAD)
        #expect(model.todayBSDate() == BSDay(year: 2084, month: 12, day: 30))
    }

    @Test func lastSupportedDateShowsABikramSambatDate() {
        let model = menuBar(lastSupportedAD)
        let title = model.title(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))
        #expect(title != Strings.menuBarBeyondRange)
        // Menu-bar form is short: day + month, no year.
        #expect(title == "30 Chaitra")
    }

    // MARK: - Past the boundary

    @Test func firstUnsupportedDateHasNoBikramSambatAnswer() {
        #expect(clock(firstUnsupportedAD).todayBSDate() == nil)
    }

    @Test func menuBarShowsBoundaryMarkerNotABareDash() {
        let title = menuBar(firstUnsupportedAD)
            .title(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))
        #expect(title == Strings.menuBarBeyondRange)
        // A bare em dash reads as a bug or a loading failure rather than a data limit.
        #expect(title != "—")
    }

    @Test func gregorianAndClocksSurviveTheBoundary() {
        let model = clock(firstUnsupportedAD)
        #expect(model.gregorianString(settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == "13 April 2028")
        #expect(model.nptTimeString(digits: .latin) == "11:45:00")
    }

    @Test func weekdaySurvivesTheBoundary() {
        // 13 April 2028 is a Thursday. The weekday belongs to the civil day, so
        // it must not depend on a Bikram Sambat conversion succeeding.
        let model = clock(firstUnsupportedAD)
        #expect(model.weekdayString(style: .transliterated) == "Thursday")
        #expect(model.weekdayString(style: .nepali) == "बिही")
    }

    @Test func weekdayIsUnchangedAcrossTheBoundary() {
        // The two dates are consecutive, so consecutive weekdays.
        #expect(clock(firstUnsupportedAD).weekdayString(style: .transliterated) == "Thursday")
        #expect(clock(lastSupportedAD).weekdayString(style: .transliterated) == "Wednesday")
    }

    // MARK: - The notice names the boundary

    @Test func boundaryNoticeNamesTheLastSupportedYearInBothScripts() {
        let year = CalendarDataset.v2.supportedRange.upperBound
        #expect(year == 2084)
        #expect(Strings.supportedThrough(year, digits: .latin) == "Supported through 2084 BS")
        #expect(Strings.supportedThrough(year, digits: .devanagari) == "Supported through २०८४ BS")
    }

    @Test func boundaryNoticeUsesGlossaryLanguage() {
        // CONTEXT.md avoids "BS date" as prose for Bikram Sambat.
        #expect(Strings.bsDateUnavailable == "Bikram Sambat date unavailable")
        #expect(!Strings.bsDateUnavailable.contains("BS date"))
    }
}
