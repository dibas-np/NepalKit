// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The menu-bar title's optional parts. Anchors: 27 Sep 2026 is a Sunday and
/// 11 Ashoj 2083, 28 Sep 2026 a Monday and 12 Ashoj 2083 (the same anchors as
/// `WeekdayNameTests`). Nepal Time is UTC+5:45, so 05:12:07 UTC reads 10:57:07.
struct MenuBarFormatTests {
    private static let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private static let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)
    private static let everything = MenuBarFormat(showsWeekday: true, showsYear: true, showsTime: true)

    private static func utc(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute, second: second)))
    }

    private func title(_ now: Date, _ format: MenuBarFormat, _ settings: DisplaySettings = latin) -> String? {
        formatMenuBarTitle(now: now, format: format, settings: settings, in: .v2)
    }

    @Test func standardIsEveryOptionOff() {
        #expect(MenuBarFormat.standard == MenuBarFormat(
            showsWeekday: false, showsYear: false, showsTime: false, usesTwentyFourHourClock: false, showsSeconds: false
        ))
    }

    @Test func standardFormatIsTheShortDate() throws {
        let now = try Self.utc(27, 5, 12, 7)
        #expect(title(now, .standard) == "11 Ashoj")
        #expect(title(now, .standard, Self.devanagari) == "११ असोज")
    }

    @Test func everyPartInOrderLatinTransliterated() throws {
        #expect(title(try Self.utc(27, 5, 12, 7), Self.everything) == "Sun 11 Ashoj 2083 10:57")
    }

    @Test func everyPartInOrderDevanagariNepali() throws {
        #expect(title(try Self.utc(27, 5, 12, 7), Self.everything, Self.devanagari) == "आइत ११ असोज २०८३ १०:५७")
    }

    @Test func mixedScripts() throws {
        let now = try Self.utc(27, 5, 12, 7)
        let latinNepali = DisplaySettings(digits: .latin, monthNames: .nepali)
        let devanagariTransliterated = DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        #expect(title(now, Self.everything, latinNepali) == "आइत 11 असोज 2083 10:57")
        #expect(title(now, Self.everything, devanagariTransliterated) == "Sun ११ Ashoj २०८३ १०:५७")
    }

    @Test func eachOptionAlone() throws {
        let now = try Self.utc(27, 5, 12, 7)
        #expect(title(now, MenuBarFormat(showsWeekday: true)) == "Sun 11 Ashoj")
        #expect(title(now, MenuBarFormat(showsYear: true)) == "11 Ashoj 2083")
        #expect(title(now, MenuBarFormat(showsTime: true)) == "11 Ashoj 10:57")
    }

    @Test func clockSubOptionsNeedTheTime() throws {
        let now = try Self.utc(27, 5, 12, 7)
        #expect(title(now, MenuBarFormat(usesTwentyFourHourClock: true, showsSeconds: true)) == "11 Ashoj")
    }

    @Test func twelveAndTwentyFourHourClocks() throws {
        // 17:12:07 UTC is 22:57:07 Nepal Time.
        let evening = try Self.utc(27, 17, 12, 7)
        #expect(title(evening, MenuBarFormat(showsTime: true)) == "11 Ashoj 10:57")
        #expect(title(evening, MenuBarFormat(showsTime: true, usesTwentyFourHourClock: true)) == "11 Ashoj 22:57")
        #expect(title(evening, MenuBarFormat(showsTime: true, usesTwentyFourHourClock: true, showsSeconds: true)) == "11 Ashoj 22:57:07")
        #expect(title(evening, MenuBarFormat(showsTime: true, showsSeconds: true), Self.devanagari) == "११ असोज १०:५७:०७")
    }

    @Test func twelveHourClockHasNoLeadingZeroAndTwentyFourHourDoes() throws {
        // 03:20 UTC is 09:05 Nepal Time.
        let morning = try Self.utc(27, 3, 20, 0)
        #expect(title(morning, MenuBarFormat(showsTime: true)) == "11 Ashoj 9:05")
        #expect(title(morning, MenuBarFormat(showsTime: true, usesTwentyFourHourClock: true)) == "11 Ashoj 09:05")
    }

    /// 18:15:30 UTC on 27 Sep is 00:00:30 on 28 Sep in Nepal Time: the UTC (and
    /// any western) clock still says Sunday the 27th, Nepal is on Monday,
    /// 12 Ashoj. Every part must follow Nepal Time, and do so together.
    @Test func everyPartFollowsNepalTimeAcrossMidnight() throws {
        let justAfter = try Self.utc(27, 18, 15, 30)
        #expect(title(justAfter, Self.everything) == "Mon 12 Ashoj 2083 12:00")
        #expect(title(justAfter, MenuBarFormat(showsTime: true, usesTwentyFourHourClock: true, showsSeconds: true)) == "12 Ashoj 00:00:30")

        let justBefore = try Self.utc(27, 18, 14, 30)
        #expect(title(justBefore, Self.everything) == "Sun 11 Ashoj 2083 11:59")
    }

    @Test func beyondTheSupportedRangeThereIsNoTitle() {
        // 26 Jul 2028, past the table's 12 April 2028 end.
        let beyond = Date(timeIntervalSince1970: 1_848_096_000)
        #expect(title(beyond, Self.everything) == nil)
        #expect(SpokenDate.menuBarDate(now: beyond, format: Self.everything, monthNames: .transliterated, in: .v2) == nil)
    }

    @Test func spokenFormUsesFullWeekdayLatinDigitsAndAlwaysTheYear() throws {
        let now = try Self.utc(27, 5, 12, 7)
        let spoken = { (format: MenuBarFormat, names: MonthNameStyle) in
            SpokenDate.menuBarDate(now: now, format: format, monthNames: names, in: .v2)
        }
        #expect(spoken(.standard, .transliterated) == "11 Ashoj 2083")
        #expect(spoken(Self.everything, .transliterated) == "Sunday, 11 Ashoj 2083, 10:57")
        #expect(spoken(MenuBarFormat(showsWeekday: true, showsTime: true, showsSeconds: true), .nepali) == "आइत, 11 असोज 2083, 10:57:07")
        #expect(spoken(MenuBarFormat(showsTime: true, usesTwentyFourHourClock: true), .transliterated) == "11 Ashoj 2083, 10:57")
    }

    @Test func spokenFormFollowsNepalTimeAcrossMidnight() throws {
        let spoken = SpokenDate.menuBarDate(now: try Self.utc(27, 18, 15, 30), format: Self.everything, monthNames: .transliterated, in: .v2)
        #expect(spoken == "Monday, 12 Ashoj 2083, 12:00")
    }

    @Test func clockTimeInAnotherZone() throws {
        let epoch = Date(timeIntervalSince1970: 0)
        let utcPlusOne = try #require(TimeZone(secondsFromGMT: 3_600))
        #expect(formatClockTime(epoch, timeZone: utcPlusOne, usesTwentyFourHourClock: false, showsSeconds: false, digits: .latin) == "1:00")
        #expect(formatClockTime(epoch, timeZone: .gmt, usesTwentyFourHourClock: false, showsSeconds: true, digits: .latin) == "12:00:00")
        #expect(formatClockTime(epoch, timeZone: .gmt, usesTwentyFourHourClock: true, showsSeconds: false, digits: .devanagari) == "००:००")
    }

    @Test func shortWeekdayNames() {
        #expect((1 ... 7).map { shortWeekdayName(for: $0, style: .transliterated) } == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        #expect((1 ... 7).map { shortWeekdayName(for: $0, style: .nepali) } == ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"])
        #expect(shortWeekdayName(for: 0, style: .transliterated) == nil)
        #expect(shortWeekdayName(for: 8, style: .nepali) == nil)
    }
}
