// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// Today and its midnight read in a zone other than Nepal Time. Anchor: 23:30
/// UTC on 26 Sep 2026 is 05:15 NPT on Sunday 27 Sep (11 Ashoj 2083) but 19:30
/// EDT on Saturday 26 Sep (10 Ashoj 2083), so Nepal and New York disagree
/// about which day it is.
struct TimeZoneTodayTests {
    private static func newYork() throws -> TimeZone {
        try #require(TimeZone(identifier: "America/New_York"))
    }

    private static func disagreeing() throws -> Date {
        try UTCDateFixture.utc(2026, 9, 26, 23, 30)
    }

    @Test func todayDefaultsToNepalTime() throws {
        let now = try Self.disagreeing()
        #expect(GregorianDate.today(now: now) == GregorianDate(year: 2026, month: 9, day: 27))
        #expect(BikramSambatDate.today(now: now, in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
        #expect(BikramSambatDate.today(now: now, timeZone: .nepal, in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test func todayInAnotherZoneIsThatZonesCivilDay() throws {
        let now = try Self.disagreeing()
        let zone = try Self.newYork()
        #expect(GregorianDate.today(now: now, timeZone: zone) == GregorianDate(year: 2026, month: 9, day: 26))
        #expect(BikramSambatDate.today(now: now, timeZone: zone, in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 10))
    }

    @Test func nextMidnightInAnotherZone() throws {
        // 19:30 EDT on the 26th: New York's midnight is 04:00 UTC on the 27th,
        // while Nepal's next one is 18:15 UTC on the 27th.
        let now = try Self.disagreeing()
        #expect(try Self.newYork().nextMidnight(after: now) == UTCDateFixture.utc(2026, 9, 27, 4, 0))
        #expect(try TimeZone.nepal.nextMidnight(after: now) == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test("Midnight follows daylight saving: 1 Nov 2026 is 25 hours long in New York")
    func nextMidnightAcrossTheEndOfDaylightSaving() throws {
        let zone = try Self.newYork()
        // 08:00 EDT on 31 Oct; midnight is still EDT, 04:00 UTC.
        #expect(try zone.nextMidnight(after: UTCDateFixture.utc(2026, 10, 31, 12, 0)) == UTCDateFixture.utc(2026, 11, 1, 4, 0))
        // 07:00 EST on 1 Nov; the clocks went back at 02:00, so midnight is 05:00 UTC.
        #expect(try zone.nextMidnight(after: UTCDateFixture.utc(2026, 11, 1, 12, 0)) == UTCDateFixture.utc(2026, 11, 2, 5, 0))
    }
}
