// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

struct TodayIntentTests {
    private var dataset: CalendarDataset { AppData.dataset }

    @Test("Today flips at Nepal Time midnight, not UTC midnight")
    func todayIsAnchoredToNepalTime() throws {
        let before = try TestDates.utc(2025, 4, 13, 18, 14)
        let after = try TestDates.utc(2025, 4, 13, 18, 16)

        let beforeBS = BikramSambatDate.today(now: before, in: dataset)
        let afterBS = BikramSambatDate.today(now: after, in: dataset)

        #expect(beforeBS != nil && afterBS != nil)
        #expect(beforeBS?.year == 2081 && beforeBS?.month == 12)
        #expect(afterBS == BikramSambatDate(year: 2082, month: 1, day: 1))
        #expect(beforeBS != afterBS)
    }

    @Test("Oracle spot-checks: anchor and 15 Ashar 2082")
    func oracleDatesMatchTheDataset() {
        #expect(GregorianDate(BikramSambatDate(year: 2082, month: 1, day: 1), in: dataset) == GregorianDate(year: 2025, month: 4, day: 14))
        #expect(BikramSambatDate(year: 2082, month: 1, day: 1).weekday(in: dataset) == 2)
        #expect(GregorianDate(BikramSambatDate(year: 2082, month: 3, day: 15), in: dataset) == GregorianDate(year: 2025, month: 6, day: 29))
        #expect(BikramSambatDate(year: 2082, month: 3, day: 15).weekday(in: dataset) == 1)
    }

    @Test("Beyond-range today names the dataset's last year and keeps Gregorian today")
    func beyondRangeDialogUsesDatasetNumbers() throws {
        let end = try #require(dataset.gregorianEnd)
        let utc = TestDates.utcCalendar
        let lastDay = try #require(utc.date(from: DateComponents(year: end.year, month: end.month, day: end.day)))
        let past = try #require(utc.date(byAdding: .day, value: 30, to: lastDay))

        #expect(BikramSambatDate.today(now: past, in: dataset) == nil)

        let dialog = String(localized: TodayInBikramSambatIntent.beyondRangeDialog(now: past, in: dataset))
        #expect(dialog.contains("\(dataset.supportedRange.upperBound)"))
        #expect(dialog.hasPrefix("NepalKit's Bikram Sambat data covers up to the year "))
        #expect(dialog.contains("Today is "))
    }

    @Test("Month enum covers the twelve dataset months with the spec's titles")
    func monthEnumMatchesSpecTable() {
        #expect(BikramSambatMonth.allCases.count == 12)

        for month in BikramSambatMonth.allCases {
            let representation = BikramSambatMonth.caseDisplayRepresentations[month]
            #expect(representation?.title.key == BikramSambatDate.monthNames(style: .transliterated)[month.rawValue - 1])
        }

        let allStrings = BikramSambatMonth.allCases.flatMap { month -> [String] in
            let representation = BikramSambatMonth.caseDisplayRepresentations[month]
            return [representation?.title.key ?? ""] + (representation?.synonyms.map { $0.key } ?? [])
        }
        let rejectedMangsirSpelling = "Manxsir"
        #expect(!allStrings.contains {
            $0.localizedStandardContains(rejectedMangsirSpelling) || rejectedMangsirSpelling.localizedStandardContains($0)
        })
    }

    @Test("Month tokens match exactly, so near-collisions keep their own months")
    func monthTokensMatchExactly() {
        #expect(BikramSambatDateEntity.parsing("15 Aso 2082")?.month == .ashar)
        #expect(BikramSambatDateEntity.parsing("15 Asoj 2082")?.month == .ashoj)
        #expect(BikramSambatDateEntity.parsing("15 asojh 2082")?.month == .ashoj)
        #expect(BikramSambatDateEntity.parsing("15 SHRAWAN 2082")?.month == .shrawan)
        #expect(BikramSambatDateEntity.parsing("15 Ash 2082") == nil)
        #expect(BikramSambatDateEntity.parsing("15 Asharish 2082") == nil)
    }

    @Test("Entity id round-trips through its text identity")
    func entityIdRoundTrip() throws {
        let bs = BikramSambatDate(year: 2082, month: 3, day: 15)
        let entity = try #require(BikramSambatDateEntity(bsDay: bs, monthNames: .transliterated))

        #expect(entity.id == "2082-3-15")

        let rebuilt = try #require(BikramSambatDateEntity(idString: entity.id))
        #expect(rebuilt.year == 2082 && rebuilt.month == .ashar && rebuilt.day == 15)
        #expect(BikramSambatDateEntity(bsDay: BikramSambatDate(year: 2082, month: 13, day: 1)) == nil)
        #expect(BikramSambatDateEntity(idString: "2082-13-15") == nil)
        #expect(BikramSambatDateEntity(idString: "not-a-date") == nil)
    }

    @Test("Entity identity survives weekday presentation changes")
    func entityIdentityUsesCalendarDate() throws {
        let date = BikramSambatDate(year: 2082, month: 3, day: 15)
        let english = try #require(BikramSambatDateEntity(bsDay: date, monthNames: .transliterated))
        let nepali = try #require(BikramSambatDateEntity(bsDay: date, monthNames: .nepali))
        let restored = try #require(BikramSambatDateEntity(idString: english.id))
        #expect(english.weekday == "Sunday")
        #expect(nepali.weekday == "आइत")
        #expect(english == nepali)
        #expect(english == restored)
        #expect(Set([english, nepali, restored]).count == 1)
        #expect(english != BikramSambatDateEntity(bsDay: BikramSambatDate(year: 2082, month: 3, day: 16)))
    }

    @Test("Entity queries retain the weekday for valid calendar dates")
    func entityQueriesRetainWeekday() async throws {
        let entity = try #require(BikramSambatDateEntity(bsDay: BikramSambatDate(year: 2082, month: 3, day: 15)))
        let expected = IntentAnswers.weekdayNameString(1)
        #expect(entity.weekday == expected)
        let query = BikramSambatDateQuery()
        let rebuilt = try await query.entities(for: [entity.id])
        #expect(rebuilt == [entity])
        #expect(rebuilt.first?.weekday == expected)
        let parsed = try await query.entities(matching: "15 Ashar 2082")
        #expect(parsed == [entity])
        #expect(parsed.first?.weekday == expected)
        let suggested = try await query.suggestedEntities()
        #expect(suggested.count <= 1)
        for suggestion in suggested {
            let gregorian = try #require(GregorianDate(suggestion.bsDay, in: AppData.dataset))
            #expect(suggestion.weekday == IntentAnswers.weekdayNameString(gregorian.weekday))
            #expect(BikramSambatDateEntity(idString: suggestion.id) == suggestion)
        }
    }

    @Test("Entity construction rejects invalid and malformed calendar dates")
    func entityRejectsInvalidDates() {
        for identifier in ["2082-7-31", "2082-3-0", "2090-3-15", "2082-x-3-15", "2082--3-15"] {
            #expect(BikramSambatDateEntity(idString: identifier) == nil)
        }
        #expect(BikramSambatDateEntity.parsing("31 Kartik 2082") == nil)
        #expect(BikramSambatDateEntity(bsDay: BikramSambatDate(year: 2082, month: 7, day: 31), monthNames: .transliterated) == nil)
    }

    @Test("Entity query parses typed dates against titles and synonyms")
    func entityQueryParsing() throws {
        #expect(BikramSambatDateEntity.parsing("15 Ashar 2082")?.month == .ashar)
        #expect(BikramSambatDateEntity.parsing("15 ashar 2082")?.day == 15)
        #expect(BikramSambatDateEntity.parsing("15 Saun 2082")?.month == .shrawan)
        #expect(BikramSambatDateEntity.parsing("15 असार 2082")?.month == .ashar)
        #expect(BikramSambatDateEntity.parsing("1 Baishakh 2082")?.month == .baisakh)

        let parsed = try #require(BikramSambatDateEntity.parsing("15 Ashar 2082"))
        #expect(parsed.year == 2082 && parsed.day == 15)

        #expect(BikramSambatDateEntity.parsing("hello") == nil)
        #expect(BikramSambatDateEntity.parsing("2082") == nil)
        #expect(BikramSambatDateEntity.parsing("") == nil)
    }

    @Test("Dialogs speak Latin digits while displays render Devanagari")
    func dialogDisplaySplit() {
        let bs = BikramSambatDate(year: 2082, month: 3, day: 15)
        let spoken = IntentAnswers.spoken(bs)

        #expect(!spoken.contains(where: TestDates.devanagariDigits.contains))
        #expect(spoken.contains("15") && spoken.contains("2082"))

        let shown = bs.formatted(DisplaySettings(digits: .devanagari, monthNames: .nepali))
        #expect(shown.contains(where: TestDates.devanagariDigits.contains))
        #expect(shown != spoken)
    }

    @Test("SiriIntentError carries the dialog on every channel")
    func intentErrorCarriesDialog() {
        let error = SiriIntentError(dialog: "There is no 31 Kartik 2082 — Kartik 2082 has 30 days.")

        #expect(error.errorDescription == "There is no 31 Kartik 2082 — Kartik 2082 has 30 days.")
        #expect(String(localized: error.localizedStringResource) == "There is no 31 Kartik 2082 — Kartik 2082 has 30 days.")
    }

    @Test("Shortcuts catalog is valid JSON carrying all fifteen phrase templates")
    func shortcutsCatalogCarriesTodayPhrases() throws {
        let url = Repository.file("NepalKit/AppShortcuts.xcstrings")
        let data = try Data(contentsOf: url)
        let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = catalog?["strings"] as? [String: Any]

        for key in [
            "What is today's Nepali date with ${applicationName}",
            "What is my ${applicationName} date",
            "What is today in Bikram Sambat with ${applicationName}",
            "Convert a date to Bikram Sambat with ${applicationName}",
            "Use ${applicationName} to convert to Bikram Sambat",
            "Convert a Bikram Sambat date to Gregorian with ${applicationName}",
            "Use ${applicationName} to convert from Bikram Sambat",
            "Today's Nepali date",
            "What is ${day}'s Nepali date with ${applicationName}",
            "What was ${day}'s Nepali date with ${applicationName}",
            "What is ${day} in Bikram Sambat with ${applicationName}",
            "${day}'s Bikram Sambat date in ${applicationName}",
            "Tomorrow or yesterday",
            "Convert to Bikram Sambat",
            "Convert to Gregorian",
        ] {
            #expect(strings?[key] != nil, "catalog is missing \(key)")
        }
    }

    @Test("Today in a provisional year adds the projection clause; an attested year does not")
    func todayDialogNamesTheProjection() {
        let provisional = String(localized: TodayInBikramSambatIntent.successDialog(BikramSambatDate(year: 2084, month: 1, day: 1), weekday: 4, in: dataset))
        #expect(provisional.hasPrefix("Today is "))
        #expect(provisional.hasSuffix("2084. This year is a provisional projection, not yet in the official Nepali Patro."))
        let attested = String(localized: TodayInBikramSambatIntent.successDialog(BikramSambatDate(year: 2082, month: 1, day: 1), weekday: 2, in: dataset))
        #expect(attested.hasSuffix("2082."))
        #expect(!attested.contains("provisional"))
    }

    @Test("Running the intent answers the real today")
    func performAnswersFromTheRealClock() async throws {
        let zone = SettingsStore().timeReference.timeZone
        let before = Date()
        let result = try await TodayInBikramSambatIntent().perform()
        let after = Date()
        let todays = [before, after].map { BikramSambatDate.today(now: $0, timeZone: zone, in: dataset) }
        #expect(todays.contains(result.value?.bsDay))
    }
}
