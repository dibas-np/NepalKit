import Foundation
import Testing
import NepalKitCore

struct NextMidnightTests {

    @Test func nextMidnightIsTheSameNPTDay18_15UTC() throws {
        // 12:00 UTC on 27 Sep is 17:45 NPT; the next midnight is 18:15 UTC.
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 27, 12, 0))
        #expect(try next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test func justBeforeMidnightTheNextMidnightIsSixtySecondsAway() throws {
        // 18:14 UTC on 26 Sep is 23:59 NPT; midnight is one minute later.
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 26, 18, 14))
        #expect(try next == UTCDateFixture.utc(2026, 9, 26, 18, 15))
    }

    @Test func atMidnightTheNextMidnightIsTheFollowingDay() throws {
        // At exactly midnight the next one is a day away, not zero.
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 26, 18, 15))
        #expect(try next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test func justAfterMidnightTheNextMidnightIsAlmostAdayAway() throws {
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 26, 18, 16))
        #expect(try next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }
}
