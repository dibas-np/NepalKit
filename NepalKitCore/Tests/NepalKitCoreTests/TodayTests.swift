import Foundation
import Testing
import NepalKitCore

struct TodayTests {

    @Test func todayFollowsNPTEvenWhenUTCIsPreviousDay() throws {
        let now = try UTCDateFixture.utc(2026, 9, 26, 18, 30)

        #expect(BikramSambatDate.today(now: now, in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test func todayDuringNPTDaytime() throws {
        let now = try UTCDateFixture.utc(2026, 9, 27, 12, 0)

        #expect(BikramSambatDate.today(now: now, in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test("A system time zone west of Nepal must not move today's date")
    func todayIgnoresWestOfNPTSystemZone() throws {
        let now = try UTCDateFixture.utc(2026, 9, 26, 23, 30)

        #expect(try TodayTests.inTimeZone("America/New_York") {
            BikramSambatDate.today(now: now, in: .v2)
        } == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test("A system time zone east of Nepal must not move today's date")
    func todayIgnoresEastOfNPTSystemZone() throws {
        let now = try UTCDateFixture.utc(2026, 9, 27, 10, 0)

        #expect(try TodayTests.inTimeZone("Pacific/Kiritimati") {
            BikramSambatDate.today(now: now, in: .v2)
        } == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test func flipHappensAtNPTMidnightNotSystemMidnight() throws {
        #expect(BikramSambatDate.today(now: try UTCDateFixture.utc(2026, 9, 26, 18, 14), in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 10))
        #expect(BikramSambatDate.today(now: try UTCDateFixture.utc(2026, 9, 26, 18, 15), in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    private static func inTimeZone(_ identifier: String, _ body: () -> BikramSambatDate?) throws -> BikramSambatDate? {
        let original = NSTimeZone.default
        NSTimeZone.default = try #require(TimeZone(identifier: identifier))
        defer { NSTimeZone.default = original }
        return body()
    }
}
