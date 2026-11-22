import Foundation
import Testing
import NepalKitCore

struct FormattingTests {
    static let date = BikramSambatDate(year: 2083, month: 6, day: 11)
    static let allSettings: [DisplayFormatFixture] = [
        .init(settings: DisplaySettings(digits: .latin, monthNames: .transliterated), expected: "11 Ashoj 2083", label: "Latin + transliterated"),
        .init(settings: DisplaySettings(digits: .devanagari, monthNames: .nepali), expected: "११ असोज २०८३", label: "Devanagari + Nepali"),
        .init(settings: DisplaySettings(digits: .latin, monthNames: .nepali), expected: "11 असोज 2083", label: "Latin + Nepali"),
        .init(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated), expected: "११ Ashoj २०८३", label: "Devanagari + transliterated"),
    ]

    @Test(arguments: allSettings)
    func fullFormat(testCase: DisplayFormatFixture) {
        #expect(
            Self.date.formatted(testCase.settings) == testCase.expected,
            "\(testCase.label) should render \(testCase.expected)"
        )
    }

    @Test(arguments: [
        (DisplaySettings(digits: .latin, monthNames: .transliterated), "11 Ashoj"),
        (DisplaySettings(digits: .devanagari, monthNames: .nepali), "११ असोज"),
    ])
    func shortFormatOmitsYear(testCase: (settings: DisplaySettings, expected: String)) {
        #expect(Self.date.formatted(testCase.settings, includesYear: false) == testCase.expected)
    }

    @Test func clockRendersInTheGivenZoneAndScript() throws {
        let epoch = Date(timeIntervalSince1970: 0)
        let nepal = try #require(TimeZone(secondsFromGMT: 20_700))
        let utcPlusOne = try #require(TimeZone(secondsFromGMT: 3_600))
        #expect(DigitScript.latin.formatTime(epoch, in: nepal) == "05:45:00")
        #expect(DigitScript.devanagari.formatTime(epoch, in: nepal) == "०५:४५:००")
        #expect(DigitScript.latin.formatTime(epoch, in: utcPlusOne) == "01:00:00")
    }

    /// Switching digit script changes the glyphs, never the value: a minus
    /// sign must survive.
    @Test(arguments: [-1, -42, -2084, 0, 7, 2084, 999_999])
    func digitScriptPreservesValueAndLength(value: Int) {
        let latin = DigitScript.latin.format(value)
        let devanagari = DigitScript.devanagari.format(value)
        #expect(latin == String(value))
        #expect(devanagari.count == latin.count, "'\(latin)' and '\(devanagari)' differ in length")
        #expect(devanagari.filter(\.isNumber).count == latin.filter(\.isNumber).count)
        if value < 0 {
            #expect(devanagari.hasPrefix("-"), "sign dropped: '\(devanagari)'")
        }
    }

    @Test(arguments: [
        (1, "Baisakh", "January"),
        (12, "Chaitra", "December"),
    ])
    func monthBoundsAreInclusive(month: Int, expectedBS: String, expectedAD: String) {
        #expect(BikramSambatDate.monthName(month, style: .transliterated) == expectedBS)
        #expect(BikramSambatDate.monthName(month, style: .nepali) == BikramSambatDate.monthNames(style: .nepali)[month - 1])
        #expect(GregorianDate.monthName(month) == expectedAD)
    }

    /// An out-of-range month renders as its number instead of trapping;
    /// `Int.min` would overflow a guard that subtracts first.
    @Test(arguments: [
        (0, "0", "no month 0"),
        (-1, "-1", "below the first month"),
        (13, "13", "no month 13"),
        (99, "99", "far above the last month"),
        (.min, "-9223372036854775808", "Int.min: overflowed when the guard pre-subtracted"),
        (.max, "9223372036854775807", "Int.max: one past the last month"),
    ])
    func outOfRangeMonthRendersItsNumber(month: Int, expected: String, label: String) {
        #expect(BikramSambatDate.monthName(month, style: .transliterated) == expected, "\(label)")
        #expect(BikramSambatDate.monthName(month, style: .nepali) == expected, "\(label)")
        #expect(GregorianDate.monthName(month) == expected, "\(label)")
    }

    @Test func clockTimeInAnotherZone() throws {
        let epoch = Date(timeIntervalSince1970: 0)
        let utcPlusOne = try #require(TimeZone(secondsFromGMT: 3_600))
        #expect(DigitScript.latin.formatTime(epoch, in: utcPlusOne, twentyFourHour: false, showsSeconds: false) == "1:00")
        #expect(DigitScript.latin.formatTime(epoch, in: .gmt, twentyFourHour: false) == "12:00:00")
        #expect(DigitScript.devanagari.formatTime(epoch, in: .gmt, showsSeconds: false) == "००:००")
    }

    @Test func shortWeekdayNames() {
        #expect((1 ... 7).map { BikramSambatDate.shortWeekdayName($0, style: .transliterated) } == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        #expect((1 ... 7).map { BikramSambatDate.shortWeekdayName($0, style: .nepali) } == ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"])
        #expect(BikramSambatDate.shortWeekdayName(0, style: .transliterated) == nil)
        #expect(BikramSambatDate.shortWeekdayName(8, style: .nepali) == nil)
    }
}
