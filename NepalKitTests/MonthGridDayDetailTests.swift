// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
import NepalKitCore
@testable import NepalKit

/// The popover a day of the month grid opens: its texts, its distance from
/// today, and Copy.
@MainActor
struct MonthGridDayDetailTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    /// 1 Baisakh 2082 = 14 April 2025, a Monday, as in `MonthGridModelTests`.
    private func baisakh2082() throws -> MonthGridModel {
        MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
    }

    private func shownDays(_ model: MonthGridModel) -> [MonthGridDay] {
        model.weeks.flatMap { $0 }.compactMap { $0 }.filter(\.isInShownMonth)
    }

    @Test func distanceFromTodayCountsCivilDays() throws {
        let model = try baisakh2082()
        let days = shownDays(model)
        #expect(days.map { model.daysFromToday($0) } == (0 ..< 31).map { $0 })
        // Across the year boundary into Chaitra 2081: the day before New Year.
        model.showPreviousMonth()
        let lastOfChaitra = try #require(shownDays(model).last)
        #expect(model.daysFromToday(lastOfChaitra) == -1)
    }

    @Test func relativeDistanceNamesNearDaysAndCountsTheRest() {
        #expect(Strings.relativeDays(0, digits: .latin) == "Today")
        #expect(Strings.relativeDays(1, digits: .latin) == "Tomorrow")
        #expect(Strings.relativeDays(-1, digits: .latin) == "Yesterday")
        #expect(Strings.relativeDays(5, digits: .latin) == "In 5 days")
        #expect(Strings.relativeDays(-3, digits: .latin) == "3 days ago")
        #expect(Strings.relativeDays(12, digits: .devanagari) == "In १२ days")
        #expect(Strings.relativeDays(-400, digits: .devanagari) == "४०० days ago")
    }

    @Test func dayDetailShowsBothCalendarsAndTheDistance() throws {
        let model = try baisakh2082()
        // 6 Baisakh 2082 = 19 April 2025, a Saturday, five days after today.
        let day = try #require(shownDays(model).first { $0.bikramSambat.day == 6 })
        let latinDetail = model.detail(for: day, settings: latin)
        #expect(latinDetail.bikramSambat == "6 Baisakh 2082")
        #expect(latinDetail.gregorian == "19 April 2025 · Saturday")
        #expect(latinDetail.relative == "In 5 days")
        #expect(latinDetail.spokenBikramSambat == "6 Baisakh 2082")
        #expect(latinDetail.spokenGregorian == "19 April 2025, Saturday")
        #expect(latinDetail.spokenRelative == "In 5 days")

        let nepali = model.detail(for: day, settings: devanagari)
        #expect(nepali.bikramSambat == "६ बैशाख २०८२")
        #expect(nepali.gregorian == "१९ April २०२५ · शनि")
        #expect(nepali.relative == "In ५ days")
        // Spoken forms keep the month language but use Latin digits.
        #expect(nepali.spokenBikramSambat == "6 बैशाख 2082")
        #expect(nepali.spokenRelative == "In 5 days")

        let today = try #require(shownDays(model).first)
        #expect(model.detail(for: today, settings: latin).relative == "Today")
    }

    @Test func dayDetailKeepsCountingPastTheSupportedRange() throws {
        // Today is a day past the dataset; its last day is still a day away.
        let model = MonthGridModel(now: try TestDates.utc(2028, 4, 13, 6, 0))
        let last = try #require(shownDays(model).last)
        #expect(model.detail(for: last, settings: latin).relative == "Yesterday")
    }

    @Test func copyPutsTheShownBikramSambatDateOnThePasteboard() throws {
        let model = try baisakh2082()
        let day = try #require(shownDays(model).first)
        let detail = model.detail(for: day, settings: devanagari)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("NepalKitTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("stale", forType: .string)
        model.copy(detail, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "१ बैशाख २०८२")
        #expect(pasteboard.pasteboardItems?.count == 1)
    }
}
