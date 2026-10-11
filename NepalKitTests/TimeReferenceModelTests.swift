// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// Every surface that reads today, read in the user's own zone (ADR-0017).
///
/// Anchor: 23:30 UTC on 26 Sep 2026 is 05:15 NPT on Sunday 27 Sep, 11 Ashoj
/// 2083, but 19:30 EDT on Saturday 26 Sep, 10 Ashoj 2083 (11 Ashoj 2083 =
/// 27 Sep 2026, the converter suite's anchor). New York stands in for "my time
/// zone" because it and Nepal disagree about the day.
@MainActor
struct TimeReferenceModelTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)

    private static func newYork() throws -> TimeZone {
        try #require(TimeZone(identifier: "America/New_York"))
    }

    private static func disagreeing() throws -> Date {
        try TestDates.utc(2026, 9, 26, 23, 30)
    }

    // MARK: - Menu bar

    private func menuBar(timeZone: TimeZone = nepalTimeZone) throws -> MenuBarModel {
        MenuBarModel(now: try Self.disagreeing(), refreshes: false, schedulesMidnightFire: false, timeZone: timeZone)
    }

    @Test func menuBarTitleFollowsTheChosenZone() throws {
        #expect(try menuBar().title(settings: latin) == "11 Ashoj")
        #expect(try menuBar(timeZone: Self.newYork()).title(settings: latin) == "10 Ashoj")
    }

    @Test func settingTheZoneMovesTheTitleAndItsClockAtOnce() throws {
        let model = try menuBar()
        model.save(MenuBarFormat(showsTime: true))
        #expect(model.title(settings: latin) == "11 Ashoj 5:15")

        model.setTimeZone(try Self.newYork())

        #expect(model.title(settings: latin) == "10 Ashoj 7:30")
        #expect(model.spokenTitle(settings: latin).contains("10 Ashoj 2083, 7:30"))
    }

    @Test func midnightFireIsScheduledForTheChosenZonesMidnight() throws {
        // 19:30 EDT: New York's midnight is 4h30m away, +1s guard.
        #expect(try MenuBarModel.midnightFireInterval(after: Self.disagreeing(), in: Self.newYork()) == TimeInterval(4 * 3600 + 30 * 60 + 1))
        // 05:15 NPT: Nepal's is 18h45m away.
        #expect(try MenuBarModel.midnightFireInterval(after: Self.disagreeing()) == TimeInterval(18 * 3600 + 45 * 60 + 1))
    }

    @Test func timeTickAlignsToTheChosenZonesMinute() throws {
        // A zone 30 seconds off UTC moves the minute boundary: 05:12:07 UTC is
        // 05:12:37 there, so the next minute is 23 seconds away.
        let offset = try #require(TimeZone(secondsFromGMT: 30))
        #expect(MenuBarModel.timeTickInterval(after: try TestDates.utc(2026, 9, 27, 5, 12, 7), showsSeconds: false, in: offset) == 23)
    }

    // MARK: - Popover clock

    private func clock(_ reference: TimeReference, local: String = "America/New_York") throws -> ClockModel {
        let zone = try #require(TimeZone(identifier: local))
        return ClockModel(now: try Self.disagreeing(), localTimeZone: zone, timeReference: reference, refreshes: false)
    }

    @Test func clockReadsTodayInTheChosenZone() throws {
        let nepal = try clock(.nepal)
        let local = try clock(.local)
        #expect(nepal.todayBSDate() == BSDay(year: 2083, month: 6, day: 11))
        #expect(local.todayBSDate() == BSDay(year: 2083, month: 6, day: 10))
        #expect(local.todayADDate() == GADay(year: 2026, month: 9, day: 26))
        #expect(nepal.weekdayString(style: .transliterated) == "Sunday")
        #expect(local.weekdayString(style: .transliterated) == "Saturday")
    }

    @Test func withNepalTimeTheHeaderIsNepalAndTheRowIsLocal() throws {
        let model = try clock(.nepal)
        #expect(model.headerClockLabel == "Nepal Time")
        #expect(model.headerTimeString(digits: .latin) == "05:15:00")
        #expect(model.secondaryClockLabel == "Local")
        #expect(model.secondaryTimeString(digits: .latin) == "19:30:00")
        #expect(model.showsSecondaryClock)
    }

    @Test func withMyTimeZoneTheHeaderIsLocalAndTheRowIsNepal() throws {
        let model = try clock(.local)
        #expect(model.headerClockLabel == "Local")
        #expect(model.headerTimeString(digits: .latin) == "19:30:00")
        #expect(model.headerTimeString(digits: .devanagari) == "१९:३०:००")
        #expect(model.secondaryClockLabel == "Nepal Time")
        #expect(model.secondaryTimeString(digits: .latin) == "05:15:00")
        #expect(model.showsSecondaryClock)
    }

    @Test(arguments: TimeReference.allCases)
    func inNepalTheSecondRowIsHiddenWhicheverIsChosen(reference: TimeReference) throws {
        let model = try clock(reference, local: "Asia/Kathmandu")
        #expect(!model.showsSecondaryClock)
        #expect(model.headerTimeString(digits: .latin) == "05:15:00")
    }

    @Test func settingTheReferenceSwapsTheRoles() throws {
        let model = try clock(.nepal)
        model.setTimeReference(.local)
        #expect(model.timeReference == .local)
        #expect(model.headerClockLabel == "Local")
        #expect(model.todayBSDate() == BSDay(year: 2083, month: 6, day: 10))
    }

    // MARK: - Month grid and converter

    @Test func monthGridMarksTheChosenZonesToday() throws {
        let model = MonthGridModel(now: try Self.disagreeing(), timeZone: try Self.newYork())
        #expect(model.today == BSDay(year: 2083, month: 6, day: 10))
        #expect(model.todayGregorian == GADay(year: 2026, month: 9, day: 26))
    }

    @Test func movingTheGridsZoneMovesTodayButNotTheShownMonth() throws {
        // 18:30 UTC on 13 Apr 2025 is 00:15 NPT on 14 Apr, 1 Baisakh 2082,
        // but 14:30 EDT on 13 Apr, 31 Chaitra 2081: the zones disagree about
        // the year.
        let now = try TestDates.utc(2025, 4, 13, 18, 30)
        let model = MonthGridModel(now: now)
        #expect(model.shown == MonthGridMonth(year: 2082, month: 1))

        model.setTimeZone(try Self.newYork(), now: now)

        #expect(model.today == BSDay(year: 2081, month: 12, day: 31))
        #expect(model.shown == MonthGridMonth(year: 2082, month: 1))
        #expect(!model.isShowingTodayMonth)

        model.refreshToday(now: try TestDates.utc(2025, 4, 14, 4, 0))
        #expect(model.today == BSDay(year: 2082, month: 1, day: 1))
    }

    @Test func converterStartsOnTheChosenZonesToday() throws {
        let model = ConverterModel(now: try Self.disagreeing(), timeZone: try Self.newYork())
        #expect(model.bsDate == BSDay(year: 2083, month: 6, day: 10))
        #expect(model.adDate == GADay(year: 2026, month: 9, day: 26))
    }

    @Test func settingsPreviewRendersTheChosenZonesToday() throws {
        #expect(try DisplayPreview.todayText(now: Self.disagreeing(), timeZone: Self.newYork(), in: AppData.dataset, settings: latin)
            == "10 Ashoj 2083")
    }

    // MARK: - Siri

    @Test func siriTodayAnswersInTheChosenZone() throws {
        let nepal = try TodayInBikramSambatIntent.answer(now: Self.disagreeing(), in: AppData.dataset, timeZone: nepalTimeZone)
        let local = try TodayInBikramSambatIntent.answer(now: Self.disagreeing(), in: AppData.dataset, timeZone: Self.newYork())
        #expect(nepal.entity.bsDay == BSDay(year: 2083, month: 6, day: 11))
        #expect(local.entity.bsDay == BSDay(year: 2083, month: 6, day: 10))
    }

    @Test func siriTomorrowAndYesterdayCountFromTheChosenZonesToday() throws {
        let now = try Self.disagreeing()
        let zone = try Self.newYork()
        let tomorrow = try TomorrowInBikramSambatIntent.answer(now: now, in: AppData.dataset, monthNames: .transliterated, timeZone: zone)
        let yesterday = try YesterdayInBikramSambatIntent.answer(now: now, in: AppData.dataset, monthNames: .transliterated, timeZone: zone)
        #expect(tomorrow.entity.bsDay == BSDay(year: 2083, month: 6, day: 11))
        #expect(yesterday.entity.bsDay == BSDay(year: 2083, month: 6, day: 9))
        let nepalTomorrow = try TomorrowInBikramSambatIntent.answer(now: now, in: AppData.dataset, monthNames: .transliterated, timeZone: nepalTimeZone)
        #expect(nepalTomorrow.entity.bsDay == BSDay(year: 2083, month: 6, day: 12))
    }

    @Test func relativeDayCountsCivilDaysAcrossDaylightSaving() throws {
        // 00:30 EDT on Sunday 1 Nov 2026, the 25-hour day the clocks go back.
        // 24 hours later is 23:30 EST, still the 1st; tomorrow is the 2nd.
        let tomorrow = RelativeDay.bsDay(offset: 1, now: try TestDates.utc(2026, 11, 1, 4, 30), timeZone: try Self.newYork(), in: AppData.dataset)
        #expect(tomorrow.flatMap { bsToAD($0, in: AppData.dataset) } == GADay(year: 2026, month: 11, day: 2))
    }
}
