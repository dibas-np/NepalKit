import Foundation
import Testing
import NepalKitCore

struct FormattingTests {
    static let date = BSDay(year: 2083, month: 6, day: 11)
    static let allSettings: [(settings: DisplaySettings, expected: String, label: String)] = [
        (DisplaySettings(digits: .latin, monthNames: .transliterated), "11 Ashoj 2083", "Latin + transliterated"),
        (DisplaySettings(digits: .devanagari, monthNames: .nepali), "११ असोज २०८३", "Devanagari + Nepali"),
        (DisplaySettings(digits: .latin, monthNames: .nepali), "11 असोज 2083", "Latin + Nepali"),
        (DisplaySettings(digits: .devanagari, monthNames: .transliterated), "११ Ashoj २०८३", "Devanagari + transliterated"),
    ]

    @Test(arguments: allSettings)
    func fullFormat(testCase: (settings: DisplaySettings, expected: String, label: String)) {
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
    @Test func clockRendersInTheGivenZoneAndScript() {
        let epoch = Date(timeIntervalSince1970: 0)
        let nepal = TimeZone(secondsFromGMT: 20_700)!
        let utcPlusOne = TimeZone(secondsFromGMT: 3_600)!
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
}
