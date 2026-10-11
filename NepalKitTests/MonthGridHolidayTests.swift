// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

/// Public holidays from the gazette on the month grid: which day numbers turn
/// red, what a cell says, the lines in the day's details, and today's line.
@MainActor
struct MonthGridHolidayTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    /// 1 Kartik 2083 = 18 October 2026, a Sunday: Dashain runs 31 Ashoj to
    /// 6 Kartik and Tihar 22 to 26 Kartik.
    private func kartik2083(holidays: PublicHolidayCalendar = .gazette) throws -> MonthGridModel {
        MonthGridModel(holidays: holidays, now: try TestDates.utc(2026, 10, 18, 6, 0))
    }

    private func shownDay(_ model: MonthGridModel, _ day: Int) throws -> MonthGridDay {
        try #require(model.weeks.flatMap { $0 }.compactMap { $0 }.first { $0.isInShownMonth && $0.bikramSambat.day == day })
    }

    // MARK: - The red rule

    @Test func aNationwideHolidayIsRedWhateverItsWeekday() throws {
        let model = try kartik2083()
        // 2 Kartik: a Monday of Dashain with no festival of its own, so the
        // gazette's "Dashain holiday" names it and it carries the mark too.
        let day = try shownDay(model, 2)
        #expect(day.weekday == 2)
        #expect(day.holidayScopes == [.nationwide])
        #expect(day.isNationwideHoliday && day.isMarkedAsHoliday)
        #expect(day.showsFestivalMark)
        // 4 Kartik keeps its festival mark as well as turning red.
        let dashami = try shownDay(model, 4)
        #expect(dashami.isMarkedAsHoliday && dashami.showsFestivalMark)
    }

    @Test func aWorkingDayIsNotRedAndASaturdayStillIs() throws {
        let model = try kartik2083()
        // 8 Kartik, Kojagrat Purnima: a festival, not a holiday.
        let kojagrat = try shownDay(model, 8)
        #expect(kojagrat.holidayScopes.isEmpty)
        #expect(!kojagrat.isMarkedAsHoliday && kojagrat.showsFestivalMark)
        // 14 Kartik is a Saturday the gazette does not list.
        let saturday = try shownDay(model, 14)
        #expect(saturday.isWeeklyHoliday && saturday.holidayScopes.isEmpty)
        #expect(saturday.isMarkedAsHoliday)
    }

    @Test func aLimitedHolidayIsNotRed() throws {
        let model = try kartik2083()
        model.showPreviousMonth()
        // 9 Ashoj, Indra Jatra: a holiday in Kathmandu Valley only.
        let indraJatra = try shownDay(model, 9)
        #expect(indraJatra.weekday != MonthGridDay.weeklyHolidayWeekday)
        #expect(indraJatra.holidayScopes == [.kathmanduValley])
        #expect(!indraJatra.isNationwideHoliday && !indraJatra.isMarkedAsHoliday)
    }

    @Test func noGazetteMeansOnlySaturdaysAreRed() throws {
        let model = try kartik2083(holidays: PublicHolidayCalendar(years: [], entries: [:]))
        let days = model.weeks.flatMap { $0 }.compactMap { $0 }
        #expect(days.allSatisfy { $0.holidayScopes.isEmpty && $0.isMarkedAsHoliday == $0.isWeeklyHoliday })
    }

    // MARK: - Spoken labels and the day's details

    @Test func aHolidayCellSaysWhoItIsFor() throws {
        let model = try kartik2083()
        // 25 Kartik: Bhai Tika for everyone, Falgunanda Jayanti for the Kirat.
        let day = try shownDay(model, 25)
        #expect(model.spokenLabel(for: day, settings: latin) == "25 Kartik 2083, Wednesday, 11 November 2026, "
            + "Bhai Tika, Falgunanda Jayanti, public holiday, public holiday for the Kirat community")
        #expect(model.spokenLabel(for: day, settings: devanagari) == "25 कात्तिक 2083, बुध, 11 November 2026, "
            + "भाइटीका, फाल्गुनन्दजयन्ती, सार्वजनिक बिदा, किराँत धर्मावलम्बीका लागि बिदा")
        #expect(model.spokenLabel(for: try shownDay(model, 2), settings: latin)
            == "2 Kartik 2083, Monday, 19 October 2026, Dashain holiday, public holiday")
    }

    @Test func theDetailsHaveOneLinePerScope() throws {
        let model = try kartik2083()
        let day = try shownDay(model, 25)
        #expect(model.detail(for: day, settings: latin).holidays
            == ["Public holiday", "Public holiday for the Kirat community"])
        #expect(model.detail(for: day, settings: devanagari).holidays
            == ["सार्वजनिक बिदा", "किराँत धर्मावलम्बीका लागि बिदा"])
        #expect(model.detail(for: try shownDay(model, 9), settings: latin).holidays.isEmpty)
    }

    @Test func repeatedGazetteRowsAreOneLine() throws {
        // 18 Baisakh 2083 is three nationwide rows in the gazette.
        let model = MonthGridModel(now: try TestDates.utc(2026, 4, 15, 6, 0))
        let day = try shownDay(model, 18)
        #expect(day.bikramSambat == BSDay(year: 2083, month: 1, day: 18))
        #expect(model.detail(for: day, settings: latin).holidays == ["Public holiday"])
    }

    // MARK: - Strings

    @Test func everyScopeHasAPhraseInBothLanguages() {
        let english = PublicHoliday.Scope.allCases.map { Strings.publicHoliday($0, monthNames: .transliterated) }
        let nepali = PublicHoliday.Scope.allCases.map { Strings.publicHoliday($0, monthNames: .nepali) }
        #expect(Set(english).count == PublicHoliday.Scope.allCases.count)
        #expect(Set(nepali).count == PublicHoliday.Scope.allCases.count)
        #expect(Strings.publicHoliday(.womenObservingJitiya, monthNames: .transliterated)
            == "Public holiday for women employees who observe Jitiya")
        #expect(Strings.publicHoliday(.womenObservingJitiya, monthNames: .nepali)
            == "जितिया मनाउने महिला कर्मचारीका लागि बिदा")
        #expect(Strings.publicHoliday(.educationalInstitutions, monthNames: .transliterated)
            == "Holiday for educational institutions")
        #expect(Strings.publicHoliday(.gauraRegion, monthNames: .nepali) == "गौरा पर्व मनाउने क्षेत्रमा बिदा")
    }

    @Test func theSpokenPhraseIsAClause() {
        #expect(Strings.publicHolidaySpoken(.kathmanduValley, monthNames: .transliterated)
            == "public holiday in Kathmandu Valley")
        #expect(Strings.publicHolidaySpoken(.educationalInstitutions, monthNames: .transliterated)
            == "holiday for educational institutions")
        #expect(Strings.publicHolidaySpoken(.nationwide, monthNames: .nepali) == "सार्वजनिक बिदा")
    }

    @Test func jitiyaIsNarrowerThanTeejInTheDetails() throws {
        let model = try kartik2083()
        model.showPreviousMonth()
        #expect(model.detail(for: try shownDay(model, 18), settings: latin).holidays
            == ["Public holiday for women employees who observe Jitiya"])
        model.showPreviousMonth()
        #expect(model.detail(for: try shownDay(model, 29), settings: latin).holidays
            == ["Public holiday for women employees"])
    }

    // MARK: - Today

    @Test func todaysLineEndsWithAPublicHoliday() {
        #expect(Strings.todayFestivalLine(["Bhai Tika"], isPublicHoliday: true, monthNames: .transliterated)
            == "Bhai Tika, Public holiday")
        #expect(Strings.todayFestivalLine([], isPublicHoliday: true, monthNames: .nepali) == "सार्वजनिक बिदा")
        #expect(Strings.todayFestivalLine(["Kojagrat Purnima"], isPublicHoliday: false, monthNames: .transliterated)
            == "Kojagrat Purnima")
    }

    @Test func todaysObservancesReadBothTables() {
        let dashainMonday = TodayObservances(BSDay(year: 2083, month: 7, day: 2), festivals: .panchanga, holidays: .gazette)
        // A Dashain holiday with no festival of its own is named by the gazette.
        #expect(dashainMonday.festivals.map(\.english) == ["Dashain holiday"] && dashainMonday.isPublicHoliday)
        #expect(dashainMonday.line(monthNames: .transliterated) == "Dashain holiday, Public holiday")
        #expect(dashainMonday.line(monthNames: .nepali) == "दशैं बिदा, सार्वजनिक बिदा")
        let tika = TodayObservances(BSDay(year: 2083, month: 7, day: 4), festivals: .panchanga, holidays: .gazette)
        #expect(tika.line(monthNames: .nepali) == "विजयादशमी, सार्वजनिक बिदा")
        // Indra Jatra is a holiday only in the valley: named, not called one.
        let indraJatra = TodayObservances(BSDay(year: 2083, month: 6, day: 9), festivals: .panchanga, holidays: .gazette)
        #expect(!indraJatra.isPublicHoliday)
        #expect(indraJatra.line(monthNames: .transliterated) == "Indra Jatra")
        let workingDay = TodayObservances(BSDay(year: 2083, month: 7, day: 9), festivals: .panchanga, holidays: .gazette)
        #expect(workingDay.line(monthNames: .transliterated) == nil)
    }

    @Test func todaysAnnouncementSaysAPublicHoliday() {
        let bs = BSDay(year: 2083, month: 7, day: 2)
        let ad = GADay(year: 2026, month: 10, day: 19)
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Monday", monthNames: .transliterated, isPublicHoliday: true)
            == "2 Kartik 2083. 19 October 2026, Monday. public holiday")
        let tika = BSDay(year: 2083, month: 7, day: 4)
        let festivals = FestivalCalendar.panchanga.festivals(on: tika)
        #expect(SpokenDate.today(tika, gregorian: nil, weekday: nil, monthNames: .nepali,
                                 festivals: festivals, isPublicHoliday: true)
            == "4 कात्तिक 2083. विजयादशमी, सार्वजनिक बिदा")
    }
}
