import Foundation
import Testing
import NepalKitCore

struct NextMidnightTests {

    @Test func nextMidnightIsTheSameNPTDay18_15UTC() throws {
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 27, 12, 0))
        #expect(try next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test func justBeforeMidnightTheNextMidnightIsSixtySecondsAway() throws {
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 26, 18, 14))
        #expect(try next == UTCDateFixture.utc(2026, 9, 26, 18, 15))
    }

    @Test func atMidnightTheNextMidnightIsTheFollowingDay() throws {
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 26, 18, 15))
        #expect(try next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }

    @Test func justAfterMidnightTheNextMidnightIsAlmostAdayAway() throws {
        let next = TimeZone.nepal.nextMidnight(after: try UTCDateFixture.utc(2026, 9, 26, 18, 16))
        #expect(try next == UTCDateFixture.utc(2026, 9, 27, 18, 15))
    }
}
