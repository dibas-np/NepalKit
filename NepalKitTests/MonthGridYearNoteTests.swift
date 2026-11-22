// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct MonthGridYearNoteTests {
    private static let listedOnly2083 = "Festivals and holidays are listed for 2083 BS only."
    private static let projection2084 = "2084 BS is a projection, not yet in the official Nepali Patro."

    @Test func anAttestedListedYearHasNoNotes() throws {
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 11, 6, 0))
        #expect(model.yearNotes(digits: .latin).isEmpty)
    }

    @Test func aYearWithoutListsSaysWhichYearsHaveThem() throws {
        let model = MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
        #expect(model.yearNotes(digits: .latin) == [Self.listedOnly2083])
    }

    @Test func theProjectedYearCarriesBothNotes() throws {
        let model = MonthGridModel(now: try TestDates.utc(2027, 5, 1, 6, 0))
        #expect(model.shown.year == 2084)
        #expect(model.yearNotes(digits: .latin) == [Self.projection2084, Self.listedOnly2083])
    }

    @Test func pagingIntoAnotherYearChangesTheNotes() throws {
        let model = MonthGridModel(now: try TestDates.utc(2027, 4, 1, 6, 0))
        #expect(model.yearNotes(digits: .latin).isEmpty)
        model.showNextMonth()
        #expect(model.shown == MonthGridMonth(year: 2084, month: 1))
        #expect(model.yearNotes(digits: .latin) == [Self.projection2084, Self.listedOnly2083])
    }

    @Test func notesFollowTheDigitSetting() throws {
        let model = MonthGridModel(now: try TestDates.utc(2027, 5, 1, 6, 0))
        #expect(model.yearNotes(digits: .devanagari) == [
            "२०८४ BS is a projection, not yet in the official Nepali Patro.",
            "Festivals and holidays are listed for २०८३ BS only.",
        ])
    }

    @Test func aYearWithFestivalsButNoHolidaysNamesTheMissingList() throws {
        let model = MonthGridModel(
            festivals: FestivalCalendar(years: [2083, 2084], entries: [:]),
            holidays: PublicHolidayCalendar(years: [2083], entries: [:]),
            now: try TestDates.utc(2027, 5, 1, 6, 0)
        )
        #expect(model.yearNotes(digits: .latin) == [Self.projection2084, "Public holidays are listed for 2083 BS only."])
    }

    @Test func aYearWithHolidaysButNoFestivalsNamesTheMissingList() throws {
        let model = MonthGridModel(
            festivals: FestivalCalendar(years: [2083], entries: [:]),
            holidays: PublicHolidayCalendar(years: [2083, 2084], entries: [:]),
            now: try TestDates.utc(2027, 5, 1, 6, 0)
        )
        #expect(model.yearNotes(digits: .latin) == [Self.projection2084, "Festivals are listed for 2083 BS only."])
    }

    @Test func listsCoveringDifferentYearsAreNamedApart() throws {
        let model = MonthGridModel(
            festivals: FestivalCalendar(years: [2083, 2084], entries: [:]),
            holidays: PublicHolidayCalendar(years: [2083], entries: [:]),
            now: try TestDates.utc(2025, 4, 14, 6, 0)
        )
        #expect(model.yearNotes(digits: .latin) == [
            "Festivals are listed for 2083 and 2084 BS only. Public holidays are listed for 2083 BS only.",
        ])
    }

    @Test func noListsAtAllMeansNoListNote() throws {
        let model = MonthGridModel(
            festivals: FestivalCalendar(years: [], entries: [:]),
            holidays: PublicHolidayCalendar(years: [], entries: [:]),
            now: try TestDates.utc(2025, 4, 14, 6, 0)
        )
        #expect(model.yearNotes(digits: .latin).isEmpty)
    }
}
