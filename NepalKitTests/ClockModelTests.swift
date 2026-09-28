import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct ClockModelTests {
    static func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func model(at date: Date, local: String = "America/New_York") -> ClockModel {
        ClockModel(now: date, localTimeZone: TimeZone(identifier: local)!, refreshInterval: 3600)
    }

    @Test func bsDateFlipsAtNPTMidnight() {
        let before = model(at: Self.utcDate(2026, 9, 26, 18, 14))
        let after = model(at: Self.utcDate(2026, 9, 26, 18, 15))

        #expect(before.todayBSDate() == BSDay(year: 2083, month: 6, day: 10))
        #expect(after.todayBSDate() == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func gregorianAndBSStringsHonorSettings() {
        let clock = model(at: Self.utcDate(2026, 9, 27, 12, 0))
        let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
        let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

        #expect(clock.bsString(settings: latin) == "11 Ashoj 2083")
        #expect(clock.bsString(settings: devanagari) == "११ असोज २०८३")
        #expect(clock.gregorianString(settings: latin) == "27 September 2026")
        #expect(clock.gregorianString(settings: devanagari) == "२७ September २०२६")
    }

    @Test func weekdayHonorsMonthNameSetting() {
        // 27 Sep 2026 is a Sunday.
        let clock = model(at: Self.utcDate(2026, 9, 27, 12, 0))
        #expect(clock.weekdayString(style: .transliterated) == "Sunday")
        #expect(clock.weekdayString(style: .nepali) == "आइत")
    }

    @Test func nptClockTicksInNPTWithLocalAsReference() {
        // 18:30 UTC = 00:15 NPT next day, 14:30 in New York (EDT, UTC-4).
        let clock = model(at: Self.utcDate(2026, 9, 26, 18, 30))
        #expect(clock.nptTimeString(digits: .latin) == "00:15:00")
        #expect(clock.localTimeString(digits: .latin) == "14:30:00")
        #expect(clock.nptTimeString(digits: .devanagari) == "००:१५:००")
    }
}
