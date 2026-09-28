import Foundation
import Testing
@testable import NepalKitCore

struct TodayDisplayTests {
    static func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    @Test func gregorianFormatsLatinDigits() {
        #expect(formatAD(GADay(year: 2026, month: 9, day: 27), settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == "27 September 2026")
    }

    @Test func gregorianHonorsDevanagariDigits() {
        #expect(formatAD(GADay(year: 2026, month: 9, day: 27), settings: DisplaySettings(digits: .devanagari, monthNames: .nepali)) == "२७ September २०२६")
    }

    @Test func nptClockShowsNPTTime() {
        // 18:30 UTC on 26 Sep is 00:15 NPT on 27 Sep.
        let now = Self.utcDate(2026, 9, 26, 18, 30)
        #expect(formatClock(now, timeZone: nepalTimeZone, digits: .latin) == "00:15:00")
    }

    @Test func clockHonorsDevanagariDigits() {
        let now = Self.utcDate(2026, 9, 27, 12, 0)
        // 12:00 UTC is 17:45 NPT.
        #expect(formatClock(now, timeZone: nepalTimeZone, digits: .devanagari) == "१७:४५:००")
    }

    @Test func clockHonorsLocalTimeZone() {
        let now = Self.utcDate(2026, 9, 27, 12, 0)
        let utc = TimeZone(secondsFromGMT: 0)!
        #expect(formatClock(now, timeZone: utc, digits: .latin) == "12:00:00")
    }

    @Test func todayADFollowsNPT() {
        #expect(todayAD(now: Self.utcDate(2026, 9, 26, 18, 30)) == GADay(year: 2026, month: 9, day: 27))
        #expect(todayAD(now: Self.utcDate(2026, 9, 26, 18, 14)) == GADay(year: 2026, month: 9, day: 26))
    }
}
