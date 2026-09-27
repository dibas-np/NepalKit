import XCTest
@testable import NepalKitCore

final class TodayTests: XCTestCase {
    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testTodayFollowsNPTEvenWhenUTCIsPreviousDay() {
        // 18:30 UTC on 26 Sep is 00:15 NPT on 27 Sep: the BS date is already the 27th's.
        let now = utcDate(2026, 9, 26, 18, 30)

        XCTAssertEqual(todayBS(now: now, in: .v1), BSDay(year: 2083, month: 6, day: 11))
    }

    func testTodayDuringNPTDaytime() {
        // 12:00 UTC on 27 Sep is 17:45 NPT the same day.
        let now = utcDate(2026, 9, 27, 12, 0)

        XCTAssertEqual(todayBS(now: now, in: .v1), BSDay(year: 2083, month: 6, day: 11))
    }
}
