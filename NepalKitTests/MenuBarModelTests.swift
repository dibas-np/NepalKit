import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

struct MidnightFireIntervalTests {
    @Test func intervalSpansTheSixHoursFifteenMinutesToMidnight() throws {
        let interval = MenuBarModel.midnightFireInterval(after: try TestDates.utc(2026, 9, 27, 12, 0))
        #expect(interval == TimeInterval(6 * 3600 + 15 * 60 + 1))
    }

    @Test func intervalOneSecondBeforeMidnightIsTwoSeconds() throws {
        // 18:14:59 UTC: next midnight is 18:15:00, +1s guard makes 2.
        let interval = MenuBarModel.midnightFireInterval(after: try TestDates.utc(2026, 9, 26, 18, 14, 59))
        #expect(interval == 2)
    }

    @Test func intervalAtMidnightTargetsTomorrow() throws {
        let interval = MenuBarModel.midnightFireInterval(after: try TestDates.utc(2026, 9, 26, 18, 15, 0))
        #expect(interval == TimeInterval(24 * 3600 + 1))
    }
}
