// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct MonthGridFestivalTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    @Test func aFestivalDayCarriesItsFestivalsAndTheMark() throws {
        let model = try MonthGridModel.kartik2083()
        let dashami = try model.shownDay(4)
        #expect(dashami.festivals.map(\.english) == ["Vijaya Dashami (Dashain Tika)"])
        #expect(dashami.showsFestivalMark)
        let plain = try model.shownDay(9)
        #expect(plain.festivals.isEmpty)
        #expect(!plain.showsFestivalMark)
        let dashainHoliday = try model.shownDay(2)
        #expect(dashainHoliday.festivals.map(\.english) == ["Dashain holiday"])
        #expect(dashainHoliday.showsFestivalMark)
    }

    @Test func aNeighbouringMonthsFestivalIsNotMarked() throws {
        let mangsir1 = BikramSambatDate(year: 2083, month: 8, day: 1)
        let festival = Festival(nepali: "परीक्षण", english: "Test Day")
        let model = try MonthGridModel.kartik2083(festivals: FestivalCalendar(years: [2083], entries: [mangsir1: [festival]]))
        let spill = try #require(model.cells.first { $0.bikramSambat == mangsir1 })
        #expect(!spill.isInShownMonth)
        #expect(spill.festivals == [festival])
        #expect(!spill.showsFestivalMark)
        model.showNextMonth()
        #expect(try model.shownDay(1).showsFestivalMark)
    }

    @Test func aYearWithoutFestivalDataMarksNothing() throws {
        let model = MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
        #expect(model.cells.allSatisfy { $0.festivals.isEmpty && !$0.showsFestivalMark })
    }

    @Test func theCellSaysItsFestivalsAfterItsDate() throws {
        let model = try MonthGridModel.kartik2083()
        let dashami = try model.shownDay(4)
        #expect(model.spokenLabel(for: dashami, settings: latin)
            == "4 Kartik 2083, Wednesday, 21 October 2026, Vijaya Dashami (Dashain Tika), public holiday")
        #expect(model.spokenLabel(for: dashami, settings: devanagari)
            == "4 कात्तिक 2083, बुध, 21 October 2026, विजयादशमी, सार्वजनिक बिदा")
        #expect(model.spokenLabel(for: try model.shownDay(9), settings: latin)
            == "9 Kartik 2083, Monday, 26 October 2026")
    }

    @Test func theDetailsNameTheFestivalsInBothChannels() throws {
        let model = try MonthGridModel.kartik2083()
        let day = try model.shownDay(24)
        let nepali = model.detail(for: day, settings: devanagari)
        #expect(nepali.festivals == ["गोवर्धनपूजा", "म्हपूजा", "ने.सं.११४७ प्रारम्भ"])
        #expect(nepali.spokenFestivals == ["गोवर्धनपूजा", "म्हपूजा", "ने.सं.1147 प्रारम्भ"])
        let english = model.detail(for: day, settings: latin)
        #expect(english.festivals == ["Govardhan Puja", "Mha Puja", "Nepal Sambat New Year 1147"])
        #expect(english.spokenFestivals == english.festivals)

        let plain = model.detail(for: try model.shownDay(9), settings: latin)
        #expect(plain.festivals.isEmpty && plain.spokenFestivals.isEmpty)
    }

    @Test func todaysAnnouncementEndsWithTodaysFestivals() {
        let bs = BikramSambatDate(year: 2083, month: 7, day: 24)
        let ad = GregorianDate(year: 2026, month: 11, day: 10)
        let festivals = FestivalCalendar.panchanga.festivals(on: bs)
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Tuesday", monthNames: .transliterated, festivals: festivals)
            == "24 Kartik 2083. 10 November 2026, Tuesday. Govardhan Puja, Mha Puja, Nepal Sambat New Year 1147")
        #expect(SpokenDate.today(bs, gregorian: nil, weekday: nil, monthNames: .nepali, festivals: festivals)
            == "24 कात्तिक 2083. गोवर्धनपूजा, म्हपूजा, ने.सं.1147 प्रारम्भ")
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Tuesday", monthNames: .transliterated, festivals: [])
            == "24 Kartik 2083. 10 November 2026, Tuesday")
    }

    @Test func festivalNamesShareOneSeparator() {
        #expect(Strings.festivalNames(["Govardhan Puja", "Mha Puja"]) == "Govardhan Puja, Mha Puja")
        #expect(Strings.festivalNames(["Bhai Tika"]) == "Bhai Tika")
    }
}
