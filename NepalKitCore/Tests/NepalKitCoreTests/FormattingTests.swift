import XCTest
@testable import NepalKitCore

final class FormattingTests: XCTestCase {
    private let date = BSDay(year: 2083, month: 6, day: 11)

    func testLatinDigitsTransliteratedMonth() {
        XCTAssertEqual(format(date, digits: .latin, monthNames: .transliterated), "11 Ashoj 2083")
    }

    func testDevanagariDigitsNepaliMonth() {
        XCTAssertEqual(format(date, digits: .devanagari, monthNames: .nepali), "११ असोज २०८३")
    }

    func testLatinDigitsNepaliMonth() {
        XCTAssertEqual(format(date, digits: .latin, monthNames: .nepali), "11 असोज 2083")
    }

    func testDevanagariDigitsTransliteratedMonth() {
        XCTAssertEqual(format(date, digits: .devanagari, monthNames: .transliterated), "११ Ashoj २०८३")
    }

    func testShortFormatOmitsYear() {
        XCTAssertEqual(formatShort(date, digits: .latin, monthNames: .transliterated), "11 Ashoj")
        XCTAssertEqual(formatShort(date, digits: .devanagari, monthNames: .nepali), "११ असोज")
    }
}
