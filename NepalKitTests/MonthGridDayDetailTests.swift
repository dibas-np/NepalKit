// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct MonthGridDayDetailTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    @Test func distanceFromTodayCountsCivilDays() throws {
        let model = try MonthGridModel.baisakh2082()
        let days = model.shownDays
        #expect(days.map { model.daysFromToday($0) } == (0 ..< 31).map { $0 })
        model.showPreviousMonth()
        let lastOfChaitra = try #require(model.shownDays.last)
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
        let model = try MonthGridModel.baisakh2082()
        let day = try #require(model.shownDays.first { $0.bikramSambat.day == 6 })
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
        #expect(nepali.spokenBikramSambat == "6 बैशाख 2082")
        #expect(nepali.spokenRelative == "In 5 days")

        let today = try #require(model.shownDays.first)
        #expect(model.detail(for: today, settings: latin).relative == "Today")
    }

    @Test func dayDetailKeepsCountingPastTheSupportedRange() throws {
        let model = MonthGridModel(now: try TestDates.utc(2028, 4, 13, 6, 0))
        let last = try #require(model.shownDays.last)
        #expect(model.detail(for: last, settings: latin).relative == "Yesterday")
    }

    @Test func copyPutsTheShownBikramSambatDateOnThePasteboard() throws {
        let model = try MonthGridModel.baisakh2082()
        let day = try #require(model.shownDays.first)
        let detail = model.detail(for: day, settings: devanagari)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("NepalKitTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("stale", forType: .string)
        model.copy(detail, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "१ बैशाख २०८२")
        #expect(pasteboard.pasteboardItems?.count == 1)
    }
}
