import XCTest
@testable import NepalKitCore

final class FormattingTests: XCTestCase {
    private let date = BSDay(year: 2083, month: 6, day: 11)
    private let latinTransliterated = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let devanagariNepali = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    func testLatinDigitsTransliteratedMonth() {
        XCTAssertEqual(format(date, settings: latinTransliterated), "11 Ashoj 2083")
    }

    func testDevanagariDigitsNepaliMonth() {
        XCTAssertEqual(format(date, settings: devanagariNepali), "११ असोज २०८३")
    }

    func testLatinDigitsNepaliMonth() {
        XCTAssertEqual(
            format(date, settings: DisplaySettings(digits: .latin, monthNames: .nepali)),
            "11 असोज 2083"
        )
    }

    func testDevanagariDigitsTransliteratedMonth() {
        XCTAssertEqual(
            format(date, settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated)),
            "११ Ashoj २०८३"
        )
    }

    func testShortFormatOmitsYear() {
        XCTAssertEqual(formatShort(date, settings: latinTransliterated), "11 Ashoj")
        XCTAssertEqual(formatShort(date, settings: devanagariNepali), "११ असोज")
    }
}
