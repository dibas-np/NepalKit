// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The Display section's live preview: today's date rendered with the picked
/// settings, nil when today has no Bikram Sambat answer.
///
/// The oracle date is the one ticket 04 computed independently: noon UTC on
/// 29 June 2025 is 15 Ashar 2082 in Nepal Time (17:45 NPT, same civil day).
struct DisplayPreviewTests {
    private var dataset: CalendarDataset { AppData.dataset }
    private var now: Date {
        get throws { try TestDates.utc(2025, 6, 29, 12, 0) }
    }

    private static var devanagariDigits: Set<Character> {
        ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
    }

    @Test("Latin digits with transliterated month names read like the menu bar")
    func latinTransliterated() throws {
        let text = DisplayPreview.todayText(
            now: try now, in: dataset,
            settings: DisplaySettings(digits: .latin, monthNames: .transliterated)
        )
        #expect(text == "15 Ashar 2082")
    }

    @Test("The two pickers change independently")
    func axesAreIndependent() throws {
        // Devanagari digits with the transliterated month name: the digit
        // setting governs numerals only.
        let devanagariTransliterated = DisplayPreview.todayText(
            now: try now, in: dataset,
            settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        )
        #expect(devanagariTransliterated?.contains(where: Self.devanagariDigits.contains) == true)
        #expect(devanagariTransliterated?.contains("Ashar") == true)

        // Latin digits with the Nepali month name: the month-name setting
        // governs Bikram Sambat month names only.
        let latinNepali = DisplayPreview.todayText(
            now: try now, in: dataset,
            settings: DisplaySettings(digits: .latin, monthNames: .nepali)
        )
        #expect(latinNepali?.contains("असार") == true)
        #expect(latinNepali?.contains(where: Self.devanagariDigits.contains) == false)
    }

    @Test("Devanagari digits with Nepali month names render fully native")
    func devanagariNepali() throws {
        let text = DisplayPreview.todayText(
            now: try now, in: dataset,
            settings: DisplaySettings(digits: .devanagari, monthNames: .nepali)
        )
        #expect(text?.contains(where: Self.devanagariDigits.contains) == true)
        #expect(text?.contains("असार") == true)
        #expect(text?.contains("Ashar") == false)
    }

    @Test("A day with no Bikram Sambat answer previews as nothing")
    func outOfRangeIsNil() throws {
        // Past the dataset's end: the row hides rather than inventing a date.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let century2090 = try #require(utc.date(from: DateComponents(year: 2090, month: 1, day: 1)))
        let past = try #require(utc.date(byAdding: .day, value: 30, to: century2090))

        #expect(DisplayPreview.todayText(now: past, in: dataset, settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == nil)

        // Before the anchor is the same no-answer case, not a clamped one.
        let before = try #require(utc.date(from: DateComponents(year: 1910, month: 1, day: 1)))
        #expect(DisplayPreview.todayText(now: before, in: dataset, settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == nil)
    }
}
