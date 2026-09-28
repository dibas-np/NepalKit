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
