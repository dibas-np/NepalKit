import Foundation
import Testing
import NepalKitCore

struct TodayTests {

    @Test func todayFollowsNPTEvenWhenUTCIsPreviousDay() {
        // 18:30 UTC on 26 Sep is 00:15 NPT on 27 Sep: the date is already the 27th's.
        let now = UTCDateFixture.utc(2026, 9, 26, 18, 30)

        #expect(todayBS(now: now, in: .v2) == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func todayDuringNPTDaytime() {
        // 12:00 UTC on 27 Sep is 17:45 NPT the same day.
        let now = UTCDateFixture.utc(2026, 9, 27, 12, 0)

        #expect(todayBS(now: now, in: .v2) == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test("A system time zone west of Nepal must not move today's date")
    func todayIgnoresWestOfNPTSystemZone() {
        // 23:30 UTC on 26 Sep is 04:45 NPT on the 27th, but 19:30 on the 26th
        // in New York. A Calendar.current regression would answer the 26th.
        let now = UTCDateFixture.utc(2026, 9, 26, 23, 30)

        #expect(TodayTests.inTimeZone("America/New_York") {
            todayBS(now: now, in: .v2)
        } == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test("A system time zone east of Nepal must not move today's date")
    func todayIgnoresEastOfNPTSystemZone() {
        // 10:00 UTC on 27 Sep is 15:45 NPT the same day, but already the 28th
        // in Kiritimati (+14). A Calendar.current regression would answer the 28th.
        let now = UTCDateFixture.utc(2026, 9, 27, 10, 0)

        #expect(TodayTests.inTimeZone("Pacific/Kiritimati") {
            todayBS(now: now, in: .v2)
        } == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func flipHappensAtNPTMidnightNotSystemMidnight() {
        // NPT midnight is 18:15 UTC. One minute earlier is still the 26th.
        #expect(todayBS(now: UTCDateFixture.utc(2026, 9, 26, 18, 14), in: .v2) == BSDay(year: 2083, month: 6, day: 10))
        #expect(todayBS(now: UTCDateFixture.utc(2026, 9, 26, 18, 15), in: .v2) == BSDay(year: 2083, month: 6, day: 11))
    }

    /// Runs a closure with a process-wide default time zone, restoring it after.
    private static func inTimeZone(_ identifier: String, _ body: () -> BSDay?) -> BSDay? {
        let original = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: identifier)!
        defer { NSTimeZone.default = original }
        return body()
    }
}
