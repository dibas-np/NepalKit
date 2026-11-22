// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

struct ConversionIntentTests {
    private var dataset: CalendarDataset { AppData.dataset }

    private static func dialog(of error: Error) -> String {
        String(localized: (error as? SiriIntentError)?.localizedStringResource ?? "missing")
    }

    @Test("Named day survives: time-of-day is discarded")
    func namedDayDiscardsTimeOfDay() throws {
        let calendar = TestDates.utcCalendar
        let morning = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 0, minute: 5)))
        let night = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 23, minute: 59)))

        #expect(GregorianToBikramSambatIntent.namedDay(for: morning, calendar: calendar) == GregorianDate(year: 2025, month: 3, day: 15))
        #expect(GregorianToBikramSambatIntent.namedDay(for: night, calendar: calendar) == GregorianDate(year: 2025, month: 3, day: 15))
    }

    @Test("The default named-day reader is the user's zone on the Gregorian calendar")
    func namedDayDefaultIsGregorianInTheUserZone() {
        // Calendar.current would adopt the device's calendar identifier
        // (Buddhist, Islamic, ...), whose year components would misparse
        // every conversion into out-of-range.
        let calendar = GregorianToBikramSambatIntent.userGregorian()
        #expect(calendar.identifier == .gregorian)
        #expect(calendar.timeZone == .current)
    }

    @Test("Oracle: 15 March 2025 converts to Saturday 2 Chaitra 2081")
    func gregorianToBikramSambatOracle() async throws {
        let calendar = TestDates.utcCalendar
        let date = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 12)))
        let named = try #require(GregorianToBikramSambatIntent.namedDay(for: date, calendar: calendar))

        let converted = try #require(BikramSambatDate(named, in: dataset))
        #expect(converted == BikramSambatDate(year: 2081, month: 12, day: 2))
        #expect(named.weekday == 7)

        let monthNames = SettingsStore().settings.monthNames
        let intent = GregorianToBikramSambatIntent()
        intent.date = date
        let result = try await intent.perform()
        let expectedWeekday = monthNames == .nepali ? "शनि" : "Saturday"
        let expectedDialog = monthNames == .nepali ? "शनि, 2 चैत 2081." : "Saturday, 2 Chaitra 2081."
        #expect(result.value?.weekday == expectedWeekday)
        #expect(String(localized: GregorianToBikramSambatIntent.successDialog(converted, weekday: named.weekday, in: dataset)) == expectedDialog)
    }

    @Test("Out of range both directions names the range and the exceeded boundary")
    func gregorianOutOfRangeBothDirections() {
        let after = GregorianDate(year: 2030, month: 5, day: 12)
        let before = GregorianDate(year: 1910, month: 1, day: 1)

        #expect(BikramSambatDate(after, in: dataset) == nil)
        #expect(BikramSambatDate(before, in: dataset) == nil)

        let afterDialog = String(localized: GregorianToBikramSambatIntent.outOfRangeDialog(after, in: dataset))
        #expect(afterDialog.contains("1975") && afterDialog.contains("2084"))
        #expect(!afterDialog.contains("2,084"))
        #expect(afterDialog.contains("up to"))

        let beforeDialog = String(localized: GregorianToBikramSambatIntent.outOfRangeDialog(before, in: dataset))
        #expect(beforeDialog.contains("1975") && beforeDialog.contains("2084"))
        #expect(beforeDialog.contains("back to 13 April 1918"))
    }

    @Test("Oracle: 15 Ashar 2082 converts to 29 June 2025 at noon in the user's zone")
    func bikramSambatToGregorianOracle() async throws {
        let converted = try #require(GregorianDate(BikramSambatDate(year: 2082, month: 3, day: 15), in: dataset))
        #expect(converted == GregorianDate(year: 2025, month: 6, day: 29))

        let calendar = GregorianToBikramSambatIntent.userGregorian()
        let intent = BikramSambatToGregorianIntent()
        intent.day = 15
        intent.month = .ashar
        intent.year = 2082
        let result = try await intent.perform()
        let instant = try #require(result.value)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        #expect(parts.year == 2025 && parts.month == 6 && parts.day == 29)
        #expect(parts.hour == 12 && parts.minute == 0)
        let expectedDialog = SettingsStore().settings.monthNames == .nepali
            ? "आइत, 29 June 2025." : "Sunday, 29 June 2025."
        #expect(String(localized: BikramSambatToGregorianIntent.successDialog(converted, fromProvisionalYear: false)) == expectedDialog)
    }

    @Test(
        "The converted instant names the converted day in the user's zone",
        arguments: ["Pacific/Auckland", "Pacific/Kiritimati", "America/Los_Angeles"]
    )
    func bikramSambatToGregorianNamesTheSameDayInEveryZone(zone: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        let converted = try #require(GregorianDate(BikramSambatDate(year: 2082, month: 3, day: 15), in: dataset))

        let instant = try #require(BikramSambatToGregorianIntent.noonInUserCalendar(for: converted, calendar: calendar))

        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        #expect(parts.year == 2025 && parts.month == 6 && parts.day == 29)
        let roundTrip = try #require(GregorianToBikramSambatIntent.namedDay(for: instant, calendar: calendar))
        #expect(roundTrip == converted)
        #expect(BikramSambatDate(roundTrip, in: dataset) == BikramSambatDate(year: 2082, month: 3, day: 15))
    }

    @Test("A Gregorian day the calendar would normalize builds no instant")
    func noonInUserCalendarRejectsAnImpossibleDay() {
        #expect(BikramSambatToGregorianIntent.noonInUserCalendar(for: GregorianDate(year: 2025, month: 2, day: 30), calendar: TestDates.utcCalendar) == nil)
    }

    @Test("Round trip through the entity returns the starting civil day")
    func roundTripThroughEntity() throws {
        let bs = BikramSambatDate(year: 2082, month: 3, day: 15)
        let entity = try #require(BikramSambatDateEntity(bsDay: bs))
        #expect(entity.month == .ashar)

        let ad = try #require(GregorianDate(BikramSambatDate(year: entity.year, month: entity.month.rawValue, day: entity.day), in: dataset))
        #expect(ad == GregorianDate(year: 2025, month: 6, day: 29))
        #expect(BikramSambatDate(ad, in: dataset) == bs)
    }

    @Test("Invalid Bikram Sambat day names the month's real length")
    func bikramSambatInvalidDay() async throws {
        #expect(dataset.monthLengths(for: 2082)?[2] == 32)
        #expect(dataset.monthLengths(for: 2082)?[6] == 30)

        let valid = BikramSambatToGregorianIntent()
        valid.day = 32
        valid.month = .ashar
        valid.year = 2082
        _ = try await valid.perform()

        let invalid = BikramSambatToGregorianIntent()
        invalid.day = 31
        invalid.month = .kartik
        invalid.year = 2082
        do {
            _ = try await invalid.perform()
            Issue.record("31 Kartik 2082 should throw: Kartik 2082 has 30 days")
        } catch {
            let text = Self.dialog(of: error)
            #expect(text.contains("31"))
            #expect(text.contains("30 days"))
            #expect(text.contains("2082"))
            #expect(!text.contains("2,082"))
        }
    }

    @Test("Out-of-range Bikram Sambat year names the full boundary")
    func bikramSambatOutOfRange() async {
        let intent = BikramSambatToGregorianIntent()
        intent.day = 15
        intent.month = .ashar
        intent.year = 2090

        do {
            _ = try await intent.perform()
            Issue.record("year 2090 should throw: outside 1975 through 2084")
        } catch {
            let text = Self.dialog(of: error)
            #expect(text.contains("1975") && text.contains("2084"))
            #expect(!text.contains("2,084"))
            #expect(text.contains("That date is outside it."))
            #expect(text.contains("13 April 1918 to 12 April 2028"))
        }
    }

    @Test("Provider carries all four shortcuts")
    func providerIsWhole() {
        #expect(NepalKitShortcuts.appShortcuts.count == 4)
    }

    @Test("Gregorian to Bikram Sambat into 2084 adds the provisional clause; 2083 does not")
    func gregorianToBikramSambatProvisionalClause() {
        let provisional = String(localized: GregorianToBikramSambatIntent.successDialog(BikramSambatDate(year: 2084, month: 5, day: 22), weekday: 4, in: dataset))
        #expect(provisional.hasSuffix(" 2084. That year is a provisional projection, not yet in the official Nepali Patro."))
        let attested = String(localized: GregorianToBikramSambatIntent.successDialog(BikramSambatDate(year: 2083, month: 6, day: 11), weekday: 1, in: dataset))
        #expect(!attested.contains("provisional"))
    }

    @Test("The Gregorian success dialog adds the provisional clause for a 2084 source; 2082 does not")
    func bikramSambatToGregorianProvisionalClause() {
        #expect(dataset.isProvisional(2084))
        let provisional = String(localized: BikramSambatToGregorianIntent.successDialog(GregorianDate(year: 2027, month: 9, day: 8), fromProvisionalYear: dataset.isProvisional(2084)))
        #expect(provisional.hasSuffix("8 September 2027. That Bikram Sambat year is a provisional projection, not yet in the official Nepali Patro."))
        let attested = String(localized: BikramSambatToGregorianIntent.successDialog(GregorianDate(year: 2025, month: 6, day: 29), fromProvisionalYear: dataset.isProvisional(2082)))
        #expect(!attested.contains("provisional"))
    }

    @Test("Running the Gregorian intent past the table throws the out-of-range answer")
    func gregorianPerformOutOfRange() async throws {
        let calendar = GregorianToBikramSambatIntent.userGregorian()
        let date = try #require(calendar.date(from: DateComponents(year: 2030, month: 5, day: 12, hour: 12)))
        let intent = GregorianToBikramSambatIntent()
        intent.date = date
        do {
            _ = try await intent.perform()
            Issue.record("12 May 2030 should throw: past the supported range")
        } catch {
            let expected = GregorianToBikramSambatIntent.outOfRangeDialog(GregorianDate(year: 2030, month: 5, day: 12), in: dataset)
            #expect(Self.dialog(of: error) == String(localized: expected))
        }
    }
}
