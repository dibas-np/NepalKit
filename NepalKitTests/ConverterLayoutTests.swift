// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import CoreGraphics
import NepalKitCore
import Testing
@testable import NepalKit

/// Layout invariants of the converter's controls.
///
/// The defect these guard against is not derivable from types: a segmented
/// control and a `Picker` size themselves to content and *clip* rather than wrap
/// or shrink, so a label that is merely too long still compiles, still builds,
/// and still passes every other test. It only shows up as `ikram Sambat →
/// Gregorian` and a month reading `As…`, which is what happened when the
/// converter inherited a 340pt popover from the tabbed layout.
@MainActor
struct ConverterLayoutTests {
    /// Width inside the popover: 340pt frame less 12pt padding each side.
    private static let popoverContentWidth: CGFloat = 316

    /// Room a macOS popup-button style control needs beyond its own text:
    /// the chevron and the leading and trailing padding.
    private static let controlChrome: CGFloat = 28

    @Test func directionSegmentsFitThePopover() {
        // The two segments share one control, and the control shares the popover
        // with the tab switcher above it. Both segment labels are on screen at
        // once, so it is their sum that has to fit.
        let segments = [Strings.bsToAD, Strings.adToBS]
        let demanded = segments.reduce(CGFloat(0)) { total, label in
            total + Self.controlChrome + Self.width(of: label)
        }
        #expect(
            demanded <= Self.popoverContentWidth,
            "direction segments need ~\(Int(demanded))pt but only \(Int(Self.popoverContentWidth))pt is available"
        )
    }

    @Test func directionSegmentsAreAbbreviatedOnScreen() {
        // Pins the specific defect: the full calendar names are what overflowed.
        // The full forms must still exist for speech, or the abbreviations are
        // all a listener ever hears.
        #expect(Strings.bsToAD == "BS → AD")
        #expect(Strings.adToBS == "AD → BS")
        #expect(Strings.bsToADSpoken == "Bikram Sambat to Gregorian")
        #expect(Strings.adToBSSpoken == "Gregorian to Bikram Sambat")
    }

    @Test func everyMonthNameFitsTheMonthPicker() {
        // Every month in both scripts, because the picker shows the widest one
        // in the list and the list is a parameter, not a constant. A clipping bug
        // in Devanagari would otherwise ship unseen in a Latin-only test machine.
        for month in gregorianMonthNames {
            #expect(
                Self.controlChrome + Self.width(of: month) <= 112,
                "'\(month)' needs ~\(Int(Self.controlChrome + Self.width(of: month)))pt, floor is 112pt"
            )
        }
        for month in 1 ... 12 {
            for style in [MonthNameStyle.nepali, .transliterated] {
                let name = monthName(month: month, style: style)
                #expect(
                    Self.controlChrome + Self.width(of: name) <= 112,
                    "'\(name)' needs ~\(Int(Self.controlChrome + Self.width(of: name)))pt, floor is 112pt"
                )
            }
        }
    }

    @Test func yearAndDayValuesFitTheirPickers() {
        // The widest year is the last one in the dataset, and the widest day the
        // longest month allows. Devanagari digits are wider than Latin, so both
        // are checked.
        for style in [DigitScript.latin, .devanagari] {
            // 68pt, matching the floor in `DatePickers`. The original 62 was
            // only just enough for a Latin year and fell 2pt short for
            // Devanagari, which this test caught rather than a screenshot.
            let yearFloor: CGFloat = 68
            #expect(
                Self.controlChrome + Self.width(of: formatNumber(2084, digits: style)) <= yearFloor,
                "\(formatNumber(2084, digits: style)) does not fit the \(Int(yearFloor))pt year picker"
            )
            #expect(Self.controlChrome + Self.width(of: formatNumber(32, digits: style)) <= yearFloor)
        }
    }

    /// Conservative advance width for a string at the control's text size.
    ///
    /// Deliberately pessimistic: Devanagari conjuncts and diacritics advance
    /// further than a Latin average, and a wrong guess here must fail the test
    /// rather than pass it. A font-metrics call would be exact but would make
    /// the assertion a statement about the current OS font instead of about the
    /// labels, which is not what regressed.
    private static func width(of string: String) -> CGFloat {
        let devanagariScalars = string.unicodeScalars.filter { (0x0900 ... 0x097F).contains($0.value) }.count
        let other = string.count - devanagariScalars
        // ~7pt per Latin character, ~9pt per Devanagari cluster glyph.
        return CGFloat(other) * 7.0 + CGFloat(devanagariScalars) * 9.0
    }
}
