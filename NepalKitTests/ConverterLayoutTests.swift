// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import CoreGraphics
import NepalKitCore
import Testing
@testable import NepalKit

@MainActor
struct ConverterLayoutTests {
    /// SwiftUI's default `.padding()` on macOS, which no API reports.
    private static let defaultPadding: CGFloat = 12
    private static let popoverContentWidth = PopoverView.popoverWidth - 2 * defaultPadding

    private static let controlChrome: CGFloat = 28
    private static let textButtonPadding: CGFloat = 16
    private static let bodySizeScale: CGFloat = 1.5
    private static let headlineScale: CGFloat = 1.2
    private static let latinAdvance: CGFloat = 7
    private static let devanagariAdvance: CGFloat = 9

    @Test func directionSegmentsFitThePopover() {
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
        #expect(Strings.bsToAD == "BS → AD")
        #expect(Strings.adToBS == "AD → BS")
        #expect(Strings.bsToADSpoken == "Bikram Sambat to Gregorian")
        #expect(Strings.adToBSSpoken == "Gregorian to Bikram Sambat")
    }

    @Test func everyMonthNameFitsTheMonthPicker() {
        for month in GregorianDate.monthNames {
            #expect(
                Self.controlChrome + Self.width(of: month) <= PickerWidth.wide,
                "'\(month)' needs ~\(Int(Self.controlChrome + Self.width(of: month)))pt, floor is \(Int(PickerWidth.wide))pt"
            )
        }
        for month in 1 ... 12 {
            for style in [MonthNameStyle.nepali, .transliterated] {
                let name = BikramSambatDate.monthName(month, style: style)
                #expect(
                    Self.controlChrome + Self.width(of: name) <= PickerWidth.wide,
                    "'\(name)' needs ~\(Int(Self.controlChrome + Self.width(of: name)))pt, floor is \(Int(PickerWidth.wide))pt"
                )
            }
        }
    }

    @Test func yearAndDayValuesFitTheirPickers() {
        for style in [DigitScript.latin, .devanagari] {
            let yearFloor = PickerWidth.narrow
            #expect(
                Self.controlChrome + Self.width(of: style.format(2084)) <= yearFloor,
                "\(style.format(2084)) does not fit the \(Int(yearFloor))pt year picker"
            )
            #expect(Self.controlChrome + Self.width(of: style.format(32)) <= yearFloor)
        }
    }

    @Test func monthGridColumnsFitThePopover() {
        let column = (Self.popoverContentWidth - 6 * MonthGridView.gridSpacing) / 7
        for style in [MonthNameStyle.nepali, .transliterated] {
            for weekday in 1 ... 7 {
                let name = MonthGridModel.shortWeekdayName(weekday, style: style)
                #expect(Self.width(of: name) <= column, "'\(name)' needs ~\(Int(Self.width(of: name)))pt, column is \(Int(column))pt")
            }
        }
        for digits in [DigitScript.latin, .devanagari] {
            let day = digits.format(32)
            #expect(Self.width(of: day) * Self.bodySizeScale <= column, "\(day) does not fit a \(Int(column))pt column")
        }
    }

    @Test func monthGridHeaderFitsThePopover() {
        let chevrons = 2 * Self.controlChrome
        let today = Self.controlChrome + Self.textButtonPadding + Self.width(of: Strings.todayLabel)
        for style in [MonthNameStyle.nepali, .transliterated] {
            for month in 1 ... 12 {
                let title = "\(BikramSambatDate.monthName(month, style: style)) \(DigitScript.devanagari.format(2084))"
                let demanded = Self.width(of: title) * Self.headlineScale + today + chevrons + 3 * 4
                #expect(demanded <= Self.popoverContentWidth, "'\(title)' header needs ~\(Int(demanded))pt")
            }
        }
    }

    private static func width(of string: String) -> CGFloat {
        let devanagariScalars = string.unicodeScalars.filter { (0x0900 ... 0x097F).contains($0.value) }.count
        let other = string.count - devanagariScalars
        return CGFloat(other) * latinAdvance + CGFloat(devanagariScalars) * devanagariAdvance
    }
}
