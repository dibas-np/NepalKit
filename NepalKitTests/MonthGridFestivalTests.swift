// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

/// Festivals and national days on the month grid: which cells carry the mark,
/// what a cell says, the day details, and today's announcement (ADR-0016).
@MainActor
struct MonthGridFestivalTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    /// 1 Kartik 2083 = 18 October 2026, a Sunday, so Kartik starts the first
    /// week and 4 Kartik, Vijaya Dashami, is Wednesday 21 October.
    private func kartik2083(festivals: FestivalCalendar = .panchanga) throws -> MonthGridModel {
        MonthGridModel(festivals: festivals, now: try TestDates.utc(2026, 10, 18, 6, 0))
    }

    private func cells(_ model: MonthGridModel) -> [MonthGridDay] {
        model.weeks.flatMap { $0 }.compactMap { $0 }
    }

    private func shownDay(_ model: MonthGridModel, _ day: Int) throws -> MonthGridDay {
        try #require(cells(model).first { $0.isInShownMonth && $0.bikramSambat.day == day })
    }

    @Test func aFestivalDayCarriesItsFestivalsAndTheMark() throws {
        let model = try kartik2083()
        let dashami = try shownDay(model, 4)
        #expect(dashami.festivals.map(\.english) == ["Vijaya Dashami (Dashain Tika)"])
        #expect(dashami.showsFestivalMark)
        let plain = try shownDay(model, 2)
        #expect(plain.festivals.isEmpty)
        #expect(!plain.showsFestivalMark)
    }

    @Test func aNeighbouringMonthsFestivalIsNotMarked() throws {
        // 1 Mangsir 2083 follows Kartik's last day in the grid's last weeks.
        let mangsir1 = BSDay(year: 2083, month: 8, day: 1)
        let festival = Festival(nepali: "परीक्षण", english: "Test Day")
        let model = try kartik2083(festivals: FestivalCalendar(years: [2083], entries: [mangsir1: [festival]]))
        let spill = try #require(cells(model).first { $0.bikramSambat == mangsir1 })
        #expect(!spill.isInShownMonth)
        #expect(spill.festivals == [festival])
        #expect(!spill.showsFestivalMark)
        // Paged to its own month, the same day is marked.
        model.showNextMonth()
        #expect(try shownDay(model, 1).showsFestivalMark)
    }

    @Test func aYearWithoutFestivalDataMarksNothing() throws {
        // Baisakh 2082: the Panchanga for 2082 has not been read.
        let model = MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
        #expect(cells(model).allSatisfy { $0.festivals.isEmpty && !$0.showsFestivalMark })
    }

    @Test func theCellSaysItsFestivalsAfterItsDate() throws {
        let model = try kartik2083()
        let dashami = try shownDay(model, 4)
        // Dashami is a Dashain public holiday too, said last.
        #expect(model.spokenLabel(for: dashami, settings: latin)
            == "4 Kartik 2083, Wednesday, 21 October 2026, Vijaya Dashami (Dashain Tika), public holiday")
        #expect(model.spokenLabel(for: dashami, settings: devanagari)
            == "4 कात्तिक 2083, बुध, 21 October 2026, विजयादशमी, सार्वजनिक बिदा")
        // A working day without festivals is said exactly as before.
        #expect(model.spokenLabel(for: try shownDay(model, 9), settings: latin)
            == "9 Kartik 2083, Monday, 26 October 2026")
    }

    @Test func theDetailsNameTheFestivalsInBothChannels() throws {
        let model = try kartik2083()
        // 24 Kartik has three, one written with Devanagari digits.
        let day = try shownDay(model, 24)
        let nepali = model.detail(for: day, settings: devanagari)
        #expect(nepali.festivals == ["गोवर्धनपूजा", "म्हपूजा", "ने.सं.११४७ प्रारम्भ"])
        #expect(nepali.spokenFestivals == ["गोवर्धनपूजा", "म्हपूजा", "ने.सं.1147 प्रारम्भ"])
        let english = model.detail(for: day, settings: latin)
        #expect(english.festivals == ["Govardhan Puja", "Mha Puja", "Nepal Sambat New Year 1147"])
        #expect(english.spokenFestivals == english.festivals)

        let plain = model.detail(for: try shownDay(model, 2), settings: latin)
        #expect(plain.festivals.isEmpty && plain.spokenFestivals.isEmpty)
    }

    @Test func todaysAnnouncementEndsWithTodaysFestivals() {
        let bs = BSDay(year: 2083, month: 7, day: 24)
        let ad = GADay(year: 2026, month: 11, day: 10)
        let festivals = FestivalCalendar.panchanga.festivals(on: bs)
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Tuesday", monthNames: .transliterated, festivals: festivals)
            == "24 Kartik 2083. 10 November 2026, Tuesday. Govardhan Puja, Mha Puja, Nepal Sambat New Year 1147")
        #expect(SpokenDate.today(bs, gregorian: nil, weekday: nil, monthNames: .nepali, festivals: festivals)
            == "24 कात्तिक 2083. गोवर्धनपूजा, म्हपूजा, ने.सं.1147 प्रारम्भ")
        // No festivals, no trailing sentence.
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Tuesday", monthNames: .transliterated, festivals: [])
            == "24 Kartik 2083. 10 November 2026, Tuesday")
    }

    @Test func festivalNamesShareOneSeparator() {
        #expect(Strings.festivalNames(["Govardhan Puja", "Mha Puja"]) == "Govardhan Puja, Mha Puja")
        #expect(Strings.festivalNames(["Bhai Tika"]) == "Bhai Tika")
    }
}
