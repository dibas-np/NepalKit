import Testing
@testable import NepalKitCore

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
            format(Self.date, settings: testCase.settings) == testCase.expected,
            "\(testCase.label) should render \(testCase.expected)"
        )
    }

    @Test(arguments: [
        (DisplaySettings(digits: .latin, monthNames: .transliterated), "11 Ashoj"),
        (DisplaySettings(digits: .devanagari, monthNames: .nepali), "११ असोज"),
    ])
    func shortFormatOmitsYear(testCase: (settings: DisplaySettings, expected: String)) {
        #expect(formatShort(Self.date, settings: testCase.settings) == testCase.expected)
    }
}
