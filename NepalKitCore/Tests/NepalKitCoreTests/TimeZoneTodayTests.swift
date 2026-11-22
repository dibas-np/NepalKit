// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

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
        let now = try Self.disagreeing()
        #expect(try Self.newYork().nextMidnight(after: now) == UTCDateFixture.utc(2026, 9, 27, 4, 0))
        #expect(try TimeZone.nepal.nextMidnight(after: now) == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test("Midnight follows daylight saving: 1 Nov 2026 is 25 hours long in New York")
    func nextMidnightAcrossTheEndOfDaylightSaving() throws {
        let zone = try Self.newYork()
        #expect(try zone.nextMidnight(after: UTCDateFixture.utc(2026, 10, 31, 12, 0)) == UTCDateFixture.utc(2026, 11, 1, 4, 0))
        #expect(try zone.nextMidnight(after: UTCDateFixture.utc(2026, 11, 1, 12, 0)) == UTCDateFixture.utc(2026, 11, 2, 5, 0))
    }

    @Test("Midnight after a day that starts at 01:00: Havana springs forward at midnight on 8 Mar 2026")
    func nextMidnightAfterAMidnightTransition() throws {
        let zone = try #require(TimeZone(identifier: "America/Havana"))
        #expect(try zone.nextMidnight(after: UTCDateFixture.utc(2026, 3, 8, 12, 0)) == UTCDateFixture.utc(2026, 3, 9, 4, 0))
    }
}
