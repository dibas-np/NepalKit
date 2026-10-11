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

    /// 1 Baisakh 2082 = 14 April 2025, a Monday (Bikram Sambat New Year 2082;
    /// the same anchor `NewYearBoundaryTests` pins). 06:00 UTC is 11:45 Nepal Time.
    private func baisakh2082() throws -> MonthGridModel {
        MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
    }

    @Test func opensOnTodaysNepalTimeMonth() throws {
        // 11 Oct 2026 is 25 Ashoj 2083 (11 Ashoj 2083 = 27 Sep 2026, the
        // converter suite's anchor, plus 14 days).
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 11, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 2083, month: 6))
        #expect(model.today == BSDay(year: 2083, month: 6, day: 25))
        #expect(!model.isTodayPastSupportedRange)
        #expect(model.isShowingTodayMonth)
    }

    @Test func todayFollowsNepalTimeNotUTC() throws {
        // 13 Apr 2025 18:30 UTC is 14 Apr 00:15 Nepal Time: already 1 Baisakh 2082.
        let model = MonthGridModel(now: try TestDates.utc(2025, 4, 13, 18, 30))
        #expect(model.today == BSDay(year: 2082, month: 1, day: 1))
    }

    @Test func baisakh2082StartsOnMondayWithOneLeadingBlank() throws {
        let weeks = try baisakh2082().weeks
        // 31 days (1 Jestha 2082 = 15 May 2025) after one blank Sunday: 32
        // cells, padded to five full weeks.
        #expect(weeks.count == 5)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks[0][0] == nil)
        let first = try #require(weeks[0][1])
        #expect(first.bikramSambat == BSDay(year: 2082, month: 1, day: 1))
        #expect(first.gregorian == GADay(year: 2025, month: 4, day: 14))
        #expect(first.weekday == 2)
        let days = weeks.flatMap { $0 }.compactMap { $0 }
        #expect(days.count == 31)
        #expect(days.last?.gregorian == GADay(year: 2025, month: 5, day: 14))
        // 31 Baisakh falls on Wednesday; Thursday to Saturday are trailing blanks.
        #expect(weeks[4][3]?.bikramSambat.day == 31)
        #expect(weeks[4][4] == nil && weeks[4][5] == nil && weeks[4][6] == nil)
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
        let days = model.weeks.flatMap { $0 }.compactMap { $0 }
        // 6 Baisakh 2082 = 19 April 2025, a Saturday.
        #expect(days.filter(\.isWeeklyHoliday).map(\.bikramSambat.day) == [6, 13, 20, 27])
        #expect(days.filter(\.isWeeklyHoliday).allSatisfy { $0.weekday == 7 })
    }

    @Test func todayIsMarkedOnce() throws {
        let days = try baisakh2082().weeks.flatMap { $0 }.compactMap { $0 }
        #expect(days.filter(\.isToday).map(\.bikramSambat) == [BSDay(year: 2082, month: 1, day: 1)])
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
        // 1 Baisakh 1975 = 13 Apr 1918, the dataset's first day (CONTEXT.md,
        // *Supported range*), a Saturday.
        let model = MonthGridModel(now: try TestDates.utc(1918, 4, 13, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 1975, month: 1))
        #expect(!model.canShowPreviousMonth)
        model.showPreviousMonth()
        #expect(model.shown == MonthGridMonth(year: 1975, month: 1))
        let first = try #require(model.weeks[0][6])
        #expect(first.bikramSambat == BSDay(year: 1975, month: 1, day: 1))
        #expect(first.gregorian == GADay(year: 1918, month: 4, day: 13))
    }

    @Test func nextStopsAtChaitra2084() throws {
        // 30 Chaitra 2084 = 12 Apr 2028, the dataset's last day (CONTEXT.md).
        let model = MonthGridModel(now: try TestDates.utc(2028, 4, 12, 6, 0))
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        #expect(!model.canShowNextMonth)
        model.showNextMonth()
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        let days = model.weeks.flatMap { $0 }.compactMap { $0 }
        // 1 Chaitra 2084 = 14 Mar 2028, a Tuesday: two leading blanks.
        #expect(model.weeks[0][0] == nil && model.weeks[0][1] == nil)
        #expect(days.first?.gregorian == GADay(year: 2028, month: 3, day: 14))
        #expect(days.last?.bikramSambat == BSDay(year: 2084, month: 12, day: 30))
        #expect(days.last?.gregorian == GADay(year: 2028, month: 4, day: 12))
    }

    @Test func pastTheSupportedRangeOpensOnTheLastMonthAndSaysSo() throws {
        // 13 Apr 2028 is the first Gregorian day past the dataset.
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
        // 15 May 2025 is 1 Jestha 2082.
        model.refreshToday(now: try TestDates.utc(2025, 5, 15, 6, 0))
        #expect(model.today == BSDay(year: 2082, month: 2, day: 1))
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
        #expect(model.weekdayHeaders(settings: devanagari) == nepaliWeekdayNames)
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
        #expect(model.spokenWeekdayHeaders(settings: latin) == englishWeekdayNames)
    }

    @Test func gregorianSpanNamesBothMonths() throws {
        // Baisakh 2082 runs 14 April to 14 May 2025.
        let model = try baisakh2082()
        #expect(model.gregorianSpan(settings: latin) == "Apr–May 2025")
        #expect(model.gregorianSpan(settings: devanagari) == "Apr–May २०२५")
        #expect(model.spokenGregorianSpan() == "April to May 2025")
    }

    @Test func gregorianSpanCrossingTheYearNamesBothYears() throws {
        // Poush 2082 starts in December 2025 and ends in January 2026.
        let model = MonthGridModel(now: try TestDates.utc(2025, 12, 25, 6, 0))
        #expect(model.title(settings: latin) == "Poush 2082")
        #expect(model.gregorianSpan(settings: latin) == "Dec 2025 – Jan 2026")
        #expect(model.spokenGregorianSpan() == "December 2025 to January 2026")
    }

    @Test func todaysAnnouncementCarriesBothCalendars() {
        let bs = BSDay(year: 2083, month: 7, day: 1)
        let ad = GADay(year: 2026, month: 10, day: 18)
        #expect(SpokenDate.today(bs, gregorian: ad, weekday: "Sunday", monthNames: .transliterated)
            == "1 Kartik 2083. 18 October 2026, Sunday")
        #expect(SpokenDate.today(bs, gregorian: nil, weekday: nil, monthNames: .transliterated) == "1 Kartik 2083")
    }

    @Test func theMonthLivesInTodayNotItsOwnTab() throws {
        #expect(PopoverDestination.allCases == [.today, .convert])

        // Read from the source, as WatchPresentationWiringTests does: the
        // harness renders no views, so the composition is checked where it is
        // written. The Today branch must build the grid; Convert must not.
        let source = try String(contentsOf: Self.repositoryRoot.appending(path: "NepalKit/PopoverView.swift"), encoding: .utf8)
        let body = try #require(source.range(of: "switch destination {"))
        let today = try #require(source.range(of: "case .today:", range: body.upperBound ..< source.endIndex))
        let convert = try #require(source.range(of: "case .convert:", range: today.upperBound ..< source.endIndex))
        let todayBranch = source[today.upperBound ..< convert.lowerBound]
        #expect(todayBranch.contains("MonthGridView("))
        #expect(source.components(separatedBy: "MonthGridView(").count == 2, "built once, in Today")
    }

    /// Searched upward, because `#filePath` is the harness's symlinked path at
    /// run time (see WatchPresentationWiringTests.repositoryRoot).
    private static var repositoryRoot: URL {
        for base in [URL(fileURLWithPath: #filePath), URL(fileURLWithPath: #filePath).standardizedFileURL] {
            var dir = base.deletingLastPathComponent()
            while dir.path != "/" {
                if FileManager.default.fileExists(atPath: dir.appending(path: "NepalKit.xcodeproj").path) { return dir }
                dir = dir.deletingLastPathComponent()
            }
        }
        return URL(fileURLWithPath: #filePath)
    }
}
