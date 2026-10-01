import Foundation
import Testing
import NepalKitCore

struct TodayDisplayTests {

    @Test func gregorianFormatsLatinDigits() {
        #expect(formatAD(GADay(year: 2026, month: 9, day: 27), settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == "27 September 2026")
    }

    @Test func gregorianHonorsDevanagariDigits() {
        #expect(formatAD(GADay(year: 2026, month: 9, day: 27), settings: DisplaySettings(digits: .devanagari, monthNames: .nepali)) == "२७ September २०२६")
    }

    @Test func nptClockShowsNPTTime() throws {
        // 18:30 UTC on 26 Sep is 00:15 NPT on 27 Sep.
        let now = try UTCDateFixture.utc(2026, 9, 26, 18, 30)
        #expect(formatClock(now, timeZone: nepalTimeZone, digits: .latin) == "00:15:00")
    }

    @Test func clockHonorsDevanagariDigits() throws {
        let now = try UTCDateFixture.utc(2026, 9, 27, 12, 0)
        // 12:00 UTC is 17:45 NPT.
        #expect(formatClock(now, timeZone: nepalTimeZone, digits: .devanagari) == "१७:४५:००")
    }

    @Test func clockHonorsLocalTimeZone() throws {
        let now = try UTCDateFixture.utc(2026, 9, 27, 12, 0)
        let utc: TimeZone = .gmt
        #expect(formatClock(now, timeZone: utc, digits: .latin) == "12:00:00")
    }

    @Test func todayADFollowsNPT() throws {
        #expect(todayAD(now: try UTCDateFixture.utc(2026, 9, 26, 18, 30)) == GADay(year: 2026, month: 9, day: 27))
        #expect(todayAD(now: try UTCDateFixture.utc(2026, 9, 26, 18, 14)) == GADay(year: 2026, month: 9, day: 26))
    }
}
