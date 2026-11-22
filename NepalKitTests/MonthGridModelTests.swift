// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct MonthGridModelTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    private func baisakh2082() throws -> MonthGridModel {
        MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
    }

    @Test func opensOnTodaysNepalTimeMonth() throws {
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 11, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 2083, month: 6))
        #expect(model.today == BikramSambatDate(year: 2083, month: 6, day: 25))
        #expect(!model.isTodayPastSupportedRange)
        #expect(model.isShowingTodayMonth)
    }

    @Test func todayFollowsNepalTimeNotUTC() throws {
        let model = MonthGridModel(now: try TestDates.utc(2025, 4, 13, 18, 30))
        #expect(model.today == BikramSambatDate(year: 2082, month: 1, day: 1))
    }

    private func shownDays(_ model: MonthGridModel) -> [MonthGridDay] {
        model.weeks.flatMap { $0 }.compactMap { $0 }.filter(\.isInShownMonth)
    }

    @Test func baisakh2082StartsOnMondayAfterChaitrasLastDay() throws {
        let model = try baisakh2082()
        let weeks = model.weeks
        #expect(weeks.count == MonthGridModel.weekCount)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks.flatMap { $0 }.allSatisfy { $0 != nil })
        let first = try #require(weeks[0][1])
        #expect(first.bikramSambat == BikramSambatDate(year: 2082, month: 1, day: 1))
        #expect(first.gregorian == GregorianDate(year: 2025, month: 4, day: 14))
        #expect(first.weekday == 2)
        #expect(first.isInShownMonth)
        let days = shownDays(model)
        #expect(days.count == 31)
        #expect(days.last?.gregorian == GregorianDate(year: 2025, month: 5, day: 14))
        #expect(weeks[4][3]?.bikramSambat.day == 31)
    }

    @Test func theNeighbouringMonthsFillTheFirstAndLastWeeks() throws {
        let weeks = try baisakh2082().weeks
        let leading = try #require(weeks[0][0])
        #expect(!leading.isInShownMonth)
        #expect(leading.bikramSambat.year == 2081 && leading.bikramSambat.month == 12)
        #expect(leading.gregorian == GregorianDate(year: 2025, month: 4, day: 13))
        #expect(leading.weekday == 1)
        let trailing = weeks[4][4 ... 6].compactMap { $0 } + weeks[5].compactMap { $0 }
        #expect(trailing.map(\.bikramSambat) == (1 ... 10).map { BikramSambatDate(year: 2082, month: 2, day: $0) })
        #expect(trailing.first?.gregorian == GregorianDate(year: 2025, month: 5, day: 15))
        #expect(trailing.allSatisfy { !$0.isInShownMonth && !$0.isToday })
    }

    @Test func todayInANeighbouringMonthsSpillOverIsNotMarked() throws {
        let model = try baisakh2082()
        model.showPreviousMonth()
        let cells = model.weeks.flatMap { $0 }.compactMap { $0 }
        let spill = try #require(cells.first { $0.bikramSambat == BikramSambatDate(year: 2082, month: 1, day: 1) })
        #expect(!spill.isInShownMonth)
        #expect(!spill.isToday)
        #expect(cells.allSatisfy { !$0.isToday })
    }

    @Test func everyCellSitsInItsWeekdayColumn() throws {
        for week in try baisakh2082().weeks {
            for (column, cell) in week.enumerated() {
                if let cell { #expect(cell.weekday == column + 1) }
            }
        }
    }

    @Test func saturdayIsTheHolidayColumn() throws {
        let model = try baisakh2082()
        #expect((0 ..< 7).filter(model.isWeeklyHolidayColumn) == [6])
        let days = shownDays(model)
        #expect(days.filter(\.isWeeklyHoliday).map(\.bikramSambat.day) == [6, 13, 20, 27])
        #expect(days.filter(\.isWeeklyHoliday).allSatisfy { $0.weekday == 7 })
    }

    @Test func todayIsMarkedOnce() throws {
        let days = try baisakh2082().weeks.flatMap { $0 }.compactMap { $0 }
        #expect(days.filter(\.isToday).map(\.bikramSambat) == [BikramSambatDate(year: 2082, month: 1, day: 1)])
    }

    @Test func navigatingAwayLeavesNoTodayMarked() throws {
        let model = try baisakh2082()
        model.showNextMonth()
        #expect(model.shown == MonthGridMonth(year: 2082, month: 2))
        #expect(!model.isShowingTodayMonth)
        #expect(model.weeks.flatMap { $0 }.compactMap { $0 }.allSatisfy { !$0.isToday })
        model.showToday(now: try TestDates.utc(2025, 4, 14, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 2082, month: 1))
    }

    @Test func navigationCrossesYearBoundaries() throws {
        let model = try baisakh2082()
        model.showPreviousMonth()
        #expect(model.shown == MonthGridMonth(year: 2081, month: 12))
        model.showNextMonth()
        model.showNextMonth()
        #expect(model.shown == MonthGridMonth(year: 2082, month: 2))
    }

    @Test func previousStopsAtBaisakh1975() throws {
        let model = MonthGridModel(now: try TestDates.utc(1918, 4, 13, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 1975, month: 1))
        #expect(!model.canShowPreviousMonth)
        model.showPreviousMonth()
        #expect(model.shown == MonthGridMonth(year: 1975, month: 1))
        let first = try #require(model.weeks[0][6])
        #expect(first.bikramSambat == BikramSambatDate(year: 1975, month: 1, day: 1))
        #expect(first.gregorian == GregorianDate(year: 1918, month: 4, day: 13))
        #expect(model.weeks[0][0 ..< 6].allSatisfy { $0 == nil })
    }

    @Test func nextStopsAtChaitra2084() throws {
        let model = MonthGridModel(now: try TestDates.utc(2028, 4, 12, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        #expect(!model.canShowNextMonth)
        model.showNextMonth()
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        let days = shownDays(model)
        #expect(model.weeks[0][0]?.bikramSambat.month == 11 && model.weeks[0][1]?.bikramSambat.month == 11)
        #expect(days.first?.gregorian == GregorianDate(year: 2028, month: 3, day: 14))
        #expect(days.last?.bikramSambat == BikramSambatDate(year: 2084, month: 12, day: 30))
        #expect(days.last?.gregorian == GregorianDate(year: 2028, month: 4, day: 12))
        let cells = model.weeks.flatMap { $0 }
        let lastIndex = try #require(cells.firstIndex { $0?.bikramSambat == BikramSambatDate(year: 2084, month: 12, day: 30) })
        #expect(cells[(lastIndex + 1)...].allSatisfy { $0 == nil })
    }

    @Test func pastTheSupportedRangeOpensOnTheLastMonthAndSaysSo() throws {
        let model = MonthGridModel(now: try TestDates.utc(2028, 4, 13, 6, 0))
        #expect(model.isTodayPastSupportedRange)
        #expect(model.today == nil)
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        #expect(model.isShowingTodayMonth)
        #expect(model.weeks.flatMap { $0 }.compactMap { $0 }.allSatisfy { !$0.isToday })
        model.showPreviousMonth()
        model.showToday(now: try TestDates.utc(2028, 4, 13, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        #expect(
            Strings.monthGridPastRange(model.lastSupportedBSYear, digits: .latin)
                == "Today is past the supported range. Supported through 2084 BS."
        )
    }

    @Test func refreshMovesTodayButNotTheShownMonth() throws {
        let model = try baisakh2082()
        model.showNextMonth()
        model.refreshToday(now: try TestDates.utc(2025, 5, 15, 6, 0))
        #expect(model.today == BikramSambatDate(year: 2082, month: 2, day: 1))
        #expect(model.shown == MonthGridMonth(year: 2082, month: 2))
        #expect(model.isShowingTodayMonth)
    }

    @Test func textHonoursLatinAndTransliterated() throws {
        let model = try baisakh2082()
        #expect(model.title(settings: latin) == "Baisakh 2082")
        #expect(model.weekdayHeaders(settings: latin) == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        let first = try #require(model.weeks[0][1])
        #expect(model.dayText(first, settings: latin) == "1")
        #expect(model.gregorianDayText(first, settings: latin) == "14")
    }

    @Test func textHonoursDevanagariAndNepali() throws {
        let model = try baisakh2082()
        #expect(model.title(settings: devanagari) == "बैशाख २०८२")
        #expect(model.weekdayHeaders(settings: devanagari) == BikramSambatDate.weekdayNames(style: .nepali))
        let first = try #require(model.weeks[0][1])
        #expect(model.dayText(first, settings: devanagari) == "१")
        #expect(model.gregorianDayText(first, settings: devanagari) == "१४")
    }

    @Test func spokenFormsUseLatinDigits() throws {
        let model = try baisakh2082()
        let first = try #require(model.weeks[0][1])
        let second = try #require(model.weeks[0][2])
        #expect(model.spokenTitle(settings: devanagari) == "बैशाख 2082")
        #expect(model.spokenLabel(for: first, settings: latin) == "Today, 1 Baisakh 2082, Monday, 14 April 2025")
        #expect(model.spokenLabel(for: second, settings: latin) == "2 Baisakh 2082, Tuesday, 15 April 2025")
        #expect(model.spokenLabel(for: second, settings: devanagari) == "2 बैशाख 2082, मंगल, 15 April 2025")
        #expect(model.spokenWeekdayHeaders(settings: latin) == BikramSambatDate.weekdayNames(style: .transliterated))
    }

    @Test func gregorianSpanNamesBothMonths() throws {
        let model = try baisakh2082()
        #expect(model.gregorianSpan(settings: latin) == "Apr–May 2025")
        #expect(model.gregorianSpan(settings: devanagari) == "Apr–May २०२५")
        #expect(model.spokenGregorianSpan() == "April to May 2025")
    }

    @Test func gregorianSpanCrossingTheYearNamesBothYears() throws {
        let model = MonthGridModel(now: try TestDates.utc(2025, 12, 25, 6, 0))
        #expect(model.title(settings: latin) == "Poush 2082")
        #expect(model.gregorianSpan(settings: latin) == "Dec 2025 – Jan 2026")
        #expect(model.spokenGregorianSpan() == "December 2025 to January 2026")
    }

    @Test func todaysAnnouncementCarriesBothCalendars() {
        let bs = BikramSambatDate(year: 2083, month: 7, day: 1)
        let ad = GregorianDate(year: 2026, month: 10, day: 18)
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Sunday", monthNames: .transliterated)
            == "1 Kartik 2083. 18 October 2026, Sunday")
        #expect(SpokenDate.today(bs, gregorian: nil, weekday: nil, monthNames: .transliterated) == "1 Kartik 2083")
    }

    @Test func theHeroAnnouncesItsShownWeekdayOnce() throws {
        let clock = ClockModel(now: try TestDates.utc(2026, 10, 18, 6, 0), refreshes: false)
        let bs = try #require(clock.todayBSDate())
        let weekday = try #require(clock.weekdayString(style: .transliterated))
        let spoken = SpokenDate.today(bs, gregorian: clock.todayADDate(), weekday: weekday, monthNames: .transliterated)
        #expect(spoken.components(separatedBy: weekday).count == 2)
        #expect(spoken == "1 Kartik 2083. 18 October 2026, Sunday")
    }

    @Test func theMonthLivesInTodayNotItsOwnTab() {
        #expect(PopoverDestination.allCases == [.today, .convert])
    }
}
