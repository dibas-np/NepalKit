// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// Today, its midnight and the menu-bar title read in a zone other than Nepal
/// Time (ADR-0017). Anchor: 23:30 UTC on 26 Sep 2026 is 05:15 NPT on Sunday
/// 27 Sep (11 Ashoj 2083) but 19:30 EDT on Saturday 26 Sep (10 Ashoj 2083),
/// so Nepal and New York disagree about which day it is.
struct TimeZoneTodayTests {
    private static func newYork() throws -> TimeZone {
        try #require(TimeZone(identifier: "America/New_York"))
    }

    private static func disagreeing() throws -> Date {
        try UTCDateFixture.utc(2026, 9, 26, 23, 30)
    }

    @Test func todayDefaultsToNepalTime() throws {
        let now = try Self.disagreeing()
        #expect(todayAD(now: now) == GADay(year: 2026, month: 9, day: 27))
        #expect(todayBS(now: now, in: .v2) == BSDay(year: 2083, month: 6, day: 11))
        #expect(todayBS(now: now, timeZone: nepalTimeZone, in: .v2) == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func todayInAnotherZoneIsThatZonesCivilDay() throws {
        let now = try Self.disagreeing()
        let zone = try Self.newYork()
        #expect(todayAD(now: now, timeZone: zone) == GADay(year: 2026, month: 9, day: 26))
        #expect(todayBS(now: now, timeZone: zone, in: .v2) == BSDay(year: 2083, month: 6, day: 10))
    }

    @Test func nextMidnightInAnotherZone() throws {
        // 19:30 EDT on the 26th: New York's midnight is 04:00 UTC on the 27th,
        // while Nepal's next one is 18:15 UTC on the 27th.
        let now = try Self.disagreeing()
        #expect(try nextMidnight(after: now, in: Self.newYork()) == UTCDateFixture.utc(2026, 9, 27, 4, 0))
        #expect(try nextMidnight(after: now) == UTCDateFixture.utc(2026, 9, 27, 18, 15))
        #expect(nextNPTMidnight(after: now) == nextMidnight(after: now))
    }

    @Test("Midnight follows daylight saving: 1 Nov 2026 is 25 hours long in New York")
    func nextMidnightAcrossTheEndOfDaylightSaving() throws {
        let zone = try Self.newYork()
        // 08:00 EDT on 31 Oct; midnight is still EDT, 04:00 UTC.
        #expect(try nextMidnight(after: UTCDateFixture.utc(2026, 10, 31, 12, 0), in: zone) == UTCDateFixture.utc(2026, 11, 1, 4, 0))
        // 07:00 EST on 1 Nov; the clocks went back at 02:00, so midnight is 05:00 UTC.
        #expect(try nextMidnight(after: UTCDateFixture.utc(2026, 11, 1, 12, 0), in: zone) == UTCDateFixture.utc(2026, 11, 2, 5, 0))
    }

    @Test func menuBarTitleReadsEveryPartInTheGivenZone() throws {
        let now = try Self.disagreeing()
        let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
        let everything = MenuBarFormat(showsWeekday: true, showsYear: true, showsTime: true)
        #expect(formatMenuBarTitle(now: now, format: everything, settings: latin, in: .v2) == "Sun 11 Ashoj 2083 5:15")
        #expect(try formatMenuBarTitle(now: now, timeZone: Self.newYork(), format: everything, settings: latin, in: .v2)
            == "Sat 10 Ashoj 2083 7:30")
    }

    @Test func spokenMenuBarDateReadsEveryPartInTheGivenZone() throws {
        let now = try Self.disagreeing()
        let everything = MenuBarFormat(showsWeekday: true, showsYear: true, showsTime: true)
        #expect(try SpokenDate.menuBarDate(
            now: now, timeZone: Self.newYork(), format: everything, monthNames: .transliterated, in: .v2
        ) == "Saturday, 10 Ashoj 2083, 7:30 PM")
    }
}
