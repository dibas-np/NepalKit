import Foundation
import Testing
import NepalKitCore

struct NextMidnightTests {

    @Test func nextMidnightIsTheSameNPTDay18_15UTC() {
        // 12:00 UTC on 27 Sep is 17:45 NPT the same day: the next midnight is
        // 27 Sep 18:15 UTC, 6h15m away.
        let next = nextNPTMidnight(after: UTCDateFixture.utc(2026, 9, 27, 12, 0))
        #expect(next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test func justBeforeMidnightTheNextMidnightIsSixtySecondsAway() {
        // 18:14 UTC on 26 Sep is 23:59 NPT on the 26th; start-of-day is the
        // 26th, so the next midnight is 26 Sep 18:15 UTC — one minute later.
        let next = nextNPTMidnight(after: UTCDateFixture.utc(2026, 9, 26, 18, 14))
        #expect(next == UTCDateFixture.utc(2026, 9, 26, 18, 15))
    }

    @Test func atMidnightTheNextMidnightIsTheFollowingDay() {
        // At exactly 18:15 UTC the NPT civil day has already rolled over, so
        // the next flip is tomorrow's 18:15 UTC, not a zero interval.
        let next = nextNPTMidnight(after: UTCDateFixture.utc(2026, 9, 26, 18, 15))
        #expect(next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test func justAfterMidnightTheNextMidnightIsAlmostAdayAway() {
        let next = nextNPTMidnight(after: UTCDateFixture.utc(2026, 9, 26, 18, 16))
        #expect(next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }
}
