import Foundation
import Testing
import NepalKitCore

struct FormattingTests {
    static let date = BSDay(year: 2083, month: 6, day: 11)
    static let allSettings: [DisplayFormatFixture] = [
        .init(settings: DisplaySettings(digits: .latin, monthNames: .transliterated), expected: "11 Ashoj 2083", label: "Latin + transliterated"),
        .init(settings: DisplaySettings(digits: .devanagari, monthNames: .nepali), expected: "११ असोज २०८३", label: "Devanagari + Nepali"),
        .init(settings: DisplaySettings(digits: .latin, monthNames: .nepali), expected: "11 असोज 2083", label: "Latin + Nepali"),
        .init(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated), expected: "११ Ashoj २०८३", label: "Devanagari + transliterated"),
    ]

    @Test(arguments: allSettings)
    func fullFormat(testCase: DisplayFormatFixture) {
        #expect(
            formatBS(Self.date, settings: testCase.settings) == testCase.expected,
            "\(testCase.label) should render \(testCase.expected)"
        )
    }

    @Test(arguments: [
        (DisplaySettings(digits: .latin, monthNames: .transliterated), "11 Ashoj"),
        (DisplaySettings(digits: .devanagari, monthNames: .nepali), "११ असोज"),
    ])
    func shortFormatOmitsYear(testCase: (settings: DisplaySettings, expected: String)) {
        #expect(formatBSShort(Self.date, settings: testCase.settings) == testCase.expected)
    }

    /// One instant across two fixed zones pins the time-zone handling — the
    /// epoch reads 05:45:00 at Nepal's UTC+5:45 and 01:00:00 at UTC+1 — and the
    /// two scripts pin digit rendering. The zone pair also deliberately hits
    /// the calendar cache once as a miss and once as a reuse.
    @Test func clockRendersInTheGivenZoneAndScript() throws {
        let epoch = Date(timeIntervalSince1970: 0)
        let nepal = try #require(TimeZone(secondsFromGMT: 20_700))
        let utcPlusOne = try #require(TimeZone(secondsFromGMT: 3_600))
        #expect(formatClock(epoch, timeZone: nepal, digits: .latin) == "05:45:00")
        #expect(formatClock(epoch, timeZone: nepal, digits: .devanagari) == "०५:४५:००")
        #expect(formatClock(epoch, timeZone: utcPlusOne, digits: .latin) == "01:00:00")
    }

    /// Switching digit script must change the glyphs, never the value. An
    /// earlier implementation dropped every non-digit character, so -42
    /// rendered as "४२" — the same digits with the sign gone. This is also
    /// where the pass-through rule is covered: the arguments include negatives,
    /// so the sign (the one non-digit `formatNumber` can ever receive) must
    /// survive transliteration. Deeper pass-through cases (separators, other
    /// scripts) live in the internal `render` and are deliberately not tested
    /// here: these suites cover the public API only.
    @Test(arguments: [-1, -42, -2084, 0, 7, 2084, 999_999])
    func digitScriptPreservesValueAndLength(value: Int) {
        let latin = formatNumber(value, digits: .latin)
        let devanagari = formatNumber(value, digits: .devanagari)
        #expect(latin == String(value))
        #expect(devanagari.count == latin.count, "'\(latin)' and '\(devanagari)' differ in length")
        #expect(devanagari.filter(\.isNumber).count == latin.filter(\.isNumber).count)
        if value < 0 {
            #expect(devanagari.hasPrefix("-"), "sign dropped: '\(devanagari)'")
        }
    }

    /// Month 1 and month 12 are the two ends the name lookups accept, and they
    /// are the ends a bounds check is easiest to get wrong: these two functions
    /// used to test `indices.contains(month - 1)` and now test
    /// `(1 ... names.count).contains(month)`, and only these two months tell an
    /// off-by-one in the new form apart from the old one. Neither end is
    /// covered elsewhere — `fullFormat` and `shortFormat` only ever render
    /// month 6.
    ///
    /// The anchor is the tables themselves: 1 is Baisakh and 12 is Chaitra,
    /// Baisakh through Chaitra being the twelve months the Nepali Patro
    /// declares.
    @Test(arguments: [
        (1, "Baisakh", "January"),
        (12, "Chaitra", "December"),
    ])
    func monthBoundsAreInclusive(month: Int, expectedBS: String, expectedAD: String) {
        #expect(monthName(month: month, style: .transliterated) == expectedBS)
        #expect(monthName(month: month, style: .nepali) == nepaliMonthNames[month - 1])
        #expect(gregorianMonthName(month) == expectedAD)
    }

    /// The documented pass-through rule: an out-of-range month renders as its
    /// own number rather than a name, and — the reason the rule exists at all —
    /// it returns instead of trapping.
    ///
    /// The anchor is the two functions' own doc comments, which promise exactly
    /// this ("Out-of-range months render as their number", and the pass-through
    /// rule `devanagariString` uses). `Int.min` and `Int.max` are the cases
    /// that motivated the change: the guard used to evaluate `month - 1` before
    /// bounds-checking it, so `Int.min` overflowed and trapped inside the
    /// function whose comment promised it would never trap. A sweep that
    /// stopped at month 13 would pass against that old form too, so the
    /// extremes are the load-bearing arguments here, not decoration.
    @Test(arguments: [
        (0, "0", "no month 0"),
        (-1, "-1", "below the first month"),
        (13, "13", "no month 13"),
        (99, "99", "far above the last month"),
        (.min, "-9223372036854775808", "Int.min: overflowed when the guard pre-subtracted"),
        (.max, "9223372036854775807", "Int.max: one past the last month"),
    ])
    func outOfRangeMonthRendersItsNumber(month: Int, expected: String, label: String) {
        #expect(monthName(month: month, style: .transliterated) == expected, "\(label)")
        #expect(monthName(month: month, style: .nepali) == expected, "\(label)")
        #expect(gregorianMonthName(month) == expected, "\(label)")
    }
}
