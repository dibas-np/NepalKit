import Foundation
import Testing
import NepalKitCore

struct TodayDisplayTests {

    @Test func gregorianFormatsLatinDigits() {
        #expect(GregorianDate(year: 2026, month: 9, day: 27).formatted(digits: DisplaySettings(digits: .latin, monthNames: .transliterated).digits) == "27 September 2026")
    }

    @Test func gregorianHonorsDevanagariDigits() {
        #expect(GregorianDate(year: 2026, month: 9, day: 27).formatted(digits: DisplaySettings(digits: .devanagari, monthNames: .nepali).digits) == "२७ September २०२६")
    }

    @Test func nptClockShowsNPTTime() throws {
        let now = try UTCDateFixture.utc(2026, 9, 26, 18, 30)
        #expect(DigitScript.latin.formatTime(now, in: .nepal) == "00:15:00")
    }

    @Test func clockHonorsDevanagariDigits() throws {
        let now = try UTCDateFixture.utc(2026, 9, 27, 12, 0)
        #expect(DigitScript.devanagari.formatTime(now, in: .nepal) == "१७:४५:००")
    }

    @Test func clockHonorsLocalTimeZone() throws {
        let now = try UTCDateFixture.utc(2026, 9, 27, 12, 0)
        let utc: TimeZone = .gmt
        #expect(DigitScript.latin.formatTime(now, in: utc) == "12:00:00")
    }

    @Test func todayADFollowsNPT() throws {
        #expect(GregorianDate.today(now: try UTCDateFixture.utc(2026, 9, 26, 18, 30)) == GregorianDate(year: 2026, month: 9, day: 27))
        #expect(GregorianDate.today(now: try UTCDateFixture.utc(2026, 9, 26, 18, 14)) == GregorianDate(year: 2026, month: 9, day: 26))
    }
}
