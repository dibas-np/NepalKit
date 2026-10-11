// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The festival lookup, and sweeps over the bundled table that catch a
/// mistyped entry before a reader meets it (ADR-0016).
struct FestivalCalendarTests {
    private let calendar = FestivalCalendar.panchanga

    @Test func vijayaDashamiFallsOnFourKartik2083() throws {
        let festivals = calendar.festivals(on: BSDay(year: 2083, month: 7, day: 4))
        let dashami = try #require(festivals.first)
        #expect(festivals.count == 1)
        #expect(dashami.nepali == "विजयादशमी")
        #expect(dashami.english == "Vijaya Dashami (Dashain Tika)")
        #expect(dashami.kind == .festival)
    }

    @Test func aDayWithSeveralKeepsThePanchangasOrder() {
        let names = calendar.festivals(on: BSDay(year: 2083, month: 7, day: 24)).map(\.english)
        #expect(names == ["Govardhan Puja", "Mha Puja", "Nepal Sambat New Year 1147"])
    }

    @Test func nationalDaysAreMarkedAsSuch() throws {
        let republicDay = try #require(calendar.festivals(on: BSDay(year: 2083, month: 2, day: 15)).first)
        #expect(republicDay.kind == .nationalDay)
    }

    @Test func aDayWithoutFestivalsHasNone() {
        #expect(calendar.festivals(on: BSDay(year: 2083, month: 1, day: 2)).isEmpty)
    }

    @Test func aYearWithoutDataHasNone() {
        // 2082 is not read yet: a gap, which the lookup reports as no
        // festivals rather than guessing from another year's dates.
        #expect(!calendar.years.contains(2082))
        #expect(calendar.festivals(on: BSDay(year: 2082, month: 1, day: 1)).isEmpty)
        #expect(calendar.festivals(on: BSDay(year: 2084, month: 1, day: 1)).isEmpty)
    }

    @Test func aCalendarIsOnlyItsEntries() {
        let day = BSDay(year: 2083, month: 1, day: 1)
        let festival = Festival(nepali: "परीक्षण", english: "Test")
        let custom = FestivalCalendar(years: [2083], entries: [day: [festival]])
        #expect(custom.festivals(on: day) == [festival])
        #expect(custom.festivals(on: BSDay(year: 2083, month: 1, day: 4)).isEmpty)
        #expect(custom.allEntries.count == 1)
    }

    @Test func theNameFollowsTheMonthNameSetting() {
        let festival = Festival(nepali: "विजयादशमी", english: "Vijaya Dashami")
        #expect(festival.name(style: .nepali) == "विजयादशमी")
        #expect(festival.name(style: .transliterated) == "Vijaya Dashami")
        #expect(festival.kind == .festival)
    }

    @Test func theSpokenNameReadsDevanagariDigitsAsLatin() {
        let newYear = Festival(nepali: "ने.सं.११४७ प्रारम्भ", english: "Nepal Sambat New Year 1147")
        #expect(SpokenDate.festival(newYear, monthNames: .nepali) == "ने.सं.1147 प्रारम्भ")
        #expect(SpokenDate.festival(newYear, monthNames: .transliterated) == "Nepal Sambat New Year 1147")
        let dashami = Festival(nepali: "विजयादशमी", english: "Vijaya Dashami")
        #expect(SpokenDate.festival(dashami, monthNames: .nepali) == "विजयादशमी")
    }

    // MARK: - The bundled table

    @Test func everyEntryIsARealDayInAYearWithData() {
        var offenders: [String] = []
        for (day, _) in calendar.allEntries {
            guard calendar.years.contains(day.year) else {
                offenders.append("\(day) is outside the calendar's years")
                continue
            }
            let lengths = CalendarDataset.v2.monthLengths(for: day.year)
            if let lengths, (1 ... 12).contains(day.month), (1 ... lengths[day.month - 1]).contains(day.day) { continue }
            offenders.append("\(day) is not a day of the dataset")
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test func everyDayInTheTableHasAFestival() {
        #expect(!calendar.allEntries.isEmpty)
        #expect(calendar.allEntries.allSatisfy { !$0.festivals.isEmpty })
    }

    @Test func everyNameIsWrittenCleanly() {
        let names = calendar.allEntries.flatMap(\.festivals).flatMap { [$0.nepali, $0.english] }
        let offenders = names.filter { $0.isEmpty || $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test func noDayListsAFestivalTwice() {
        for (day, festivals) in calendar.allEntries {
            #expect(Set(festivals).count == festivals.count, "\(day) repeats a festival")
            #expect(Set(festivals.map(\.nepali)).count == festivals.count, "\(day) repeats a Nepali name")
            #expect(Set(festivals.map(\.english)).count == festivals.count, "\(day) repeats an English name")
        }
    }
}
