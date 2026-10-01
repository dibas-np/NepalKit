// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// Tickets 09 and 10: the two Shortcuts conversions.
///
/// Expected answers come from ticket 04's independently computed oracle:
/// 15 March 2025 is Saturday 2 Chaitra 2081; 15 Ashar 2082 is Sunday
/// 29 June 2025; 1 Baisakh 2082 is the dataset anchor (Monday 14 April 2025).
struct ConversionIntentTests {
    private var dataset: CalendarDataset { AppData.dataset }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private static func dialog(of error: Error) -> String {
        String(localized: (error as? SiriIntentError)?.localizedStringResource ?? "missing")
    }

    @Test("Named day survives: time-of-day is discarded")
    func namedDayDiscardsTimeOfDay() throws {
        let calendar = Self.utcCalendar()
        let morning = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 0, minute: 5)))
        let night = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 23, minute: 59)))

        #expect(GregorianToBikramSambatIntent.namedDay(for: morning, calendar: calendar) == GADay(year: 2025, month: 3, day: 15))
        #expect(GregorianToBikramSambatIntent.namedDay(for: night, calendar: calendar) == GADay(year: 2025, month: 3, day: 15))
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
        let calendar = Self.utcCalendar()
        let date = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 12)))
        let named = try #require(GregorianToBikramSambatIntent.namedDay(for: date, calendar: calendar))

        let converted = try #require(adToBS(named, in: dataset))
        #expect(converted == BSDay(year: 2081, month: 12, day: 2))
        #expect(weekday(of: named) == 7)

        let monthNames = SettingsStore().settings.monthNames
        let intent = GregorianToBikramSambatIntent()
        intent.date = date
        let result = try await intent.perform()
        let expectedWeekday = monthNames == .nepali ? "शनि" : "Saturday"
        let expectedDialog = monthNames == .nepali ? "शनि, 2 चैत 2081." : "Saturday, 2 Chaitra 2081."
        #expect(result.value?.weekday == expectedWeekday)
        #expect(String(localized: GregorianToBikramSambatIntent.successDialog(converted, weekday: weekday(of: named))) == expectedDialog)
    }

    @Test("Out of range both directions names the range and the exceeded boundary")
    func gregorianOutOfRangeBothDirections() {
        let after = GADay(year: 2030, month: 5, day: 12)
        let before = GADay(year: 1910, month: 1, day: 1)

        #expect(adToBS(after, in: dataset) == nil)
        #expect(adToBS(before, in: dataset) == nil)

        let afterDialog = String(localized: GregorianToBikramSambatIntent.outOfRangeDialog(after, in: dataset))
        #expect(afterDialog.contains("1975") && afterDialog.contains("2084"))
        #expect(!afterDialog.contains("2,084"))
        #expect(afterDialog.contains("up to"))

        let beforeDialog = String(localized: GregorianToBikramSambatIntent.outOfRangeDialog(before, in: dataset))
        #expect(beforeDialog.contains("1975") && beforeDialog.contains("2084"))
        #expect(beforeDialog.contains("back to 13 April 1918"))
    }

    @Test("A Gregorian date naming no civil day gets the month-length statement")
    func gregorianInvalidDay() throws {
        #expect(daysInGregorianMonth(year: 2025, month: 2) == 28)

        let dialog = try #require(GregorianToBikramSambatIntent.invalidDayDialog(GADay(year: 2025, month: 2, day: 30)))
        let text = String(localized: dialog)
        #expect(text.contains("30 February 2025"))
        #expect(text.contains("28 days"))
        #expect(!text.contains("2,025"))

        #expect(GregorianToBikramSambatIntent.invalidDayDialog(GADay(year: 2025, month: 3, day: 15)) == nil)
    }

    @Test("Oracle: 15 Ashar 2082 converts to 29 June 2025 at noon UTC")
    func bikramSambatToGregorianOracle() async throws {
        let converted = try #require(bsToAD(BSDay(year: 2082, month: 3, day: 15), in: dataset))
        #expect(converted == GADay(year: 2025, month: 6, day: 29))

        let instant = try #require(noonUTC(for: converted))
        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = .gmt
        let parts = gmt.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        #expect(parts.year == 2025 && parts.month == 6 && parts.day == 29)
        #expect(parts.hour == 12 && parts.minute == 0)

        let intent = BikramSambatToGregorianIntent()
        intent.day = 15
        intent.month = .ashar
        intent.year = 2082
        let result = try await intent.perform()
        #expect(result.value == instant)
        let expectedDialog = SettingsStore().settings.monthNames == .nepali
            ? "आइत, 29 June 2025." : "Sunday, 29 June 2025."
        #expect(String(localized: BikramSambatToGregorianIntent.successDialog(converted)) == expectedDialog)
    }

    @Test("Round trip through the entity returns the starting civil day")
    func roundTripThroughEntity() throws {
        let bs = BSDay(year: 2082, month: 3, day: 15)
        let entity = try #require(BikramSambatDateEntity(bsDay: bs))
        #expect(entity.month == .ashar)

        let ad = try #require(bsToAD(BSDay(year: entity.year, month: entity.month.rawValue, day: entity.day), in: dataset))
        #expect(ad == GADay(year: 2025, month: 6, day: 29))
        #expect(adToBS(ad, in: dataset) == bs)
    }

    @Test("Invalid Bikram Sambat day names the month's real length")
    func bikramSambatInvalidDay() async throws {
        // The prototype corrected ticket 03's example here: 32 Ashar 2082 is
        // valid (Ashar 2082 has 32 days), so the invalid example is 31 Kartik.
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

    @Test("Provider carries all three shortcuts; catalog carries all ten keys")
    func providerAndCatalogAreWhole() throws {
        #expect(NepalKitShortcuts.appShortcuts.count == 3)

        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        var catalogURL = directory.appending(path: "NepalKit/AppShortcuts.xcstrings")
        while !FileManager.default.fileExists(atPath: catalogURL.path), directory.path != "/" {
            directory.deleteLastPathComponent()
            catalogURL = directory.appending(path: "NepalKit/AppShortcuts.xcstrings")
        }
        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try #require(catalog?["strings"] as? [String: Any])

        for key in [
            "Convert a date to Bikram Sambat with ${applicationName}",
            "Use ${applicationName} to convert to Bikram Sambat",
            "Convert a Bikram Sambat date to Gregorian with ${applicationName}",
            "Use ${applicationName} to convert from Bikram Sambat",
            "Convert to Bikram Sambat",
            "Convert to Gregorian",
        ] {
            #expect(strings[key] != nil, "catalog is missing \(key)")
        }
    }
}
