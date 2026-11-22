// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import CoreGraphics
import NepalKitCore
import Testing
@testable import NepalKit

@MainActor
struct ConverterLayoutTests {
    private static let popoverContentWidth: CGFloat = 316

    private static let controlChrome: CGFloat = 28

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
                Self.controlChrome + Self.width(of: month) <= 112,
                "'\(month)' needs ~\(Int(Self.controlChrome + Self.width(of: month)))pt, floor is 112pt"
            )
        }
        for month in 1 ... 12 {
            for style in [MonthNameStyle.nepali, .transliterated] {
                let name = BikramSambatDate.monthName(month, style: style)
                #expect(
                    Self.controlChrome + Self.width(of: name) <= 112,
                    "'\(name)' needs ~\(Int(Self.controlChrome + Self.width(of: name)))pt, floor is 112pt"
                )
            }
        }
    }

    @Test func yearAndDayValuesFitTheirPickers() {
        for style in [DigitScript.latin, .devanagari] {
            let yearFloor: CGFloat = 68
            #expect(
                Self.controlChrome + Self.width(of: style.format(2084)) <= yearFloor,
                "\(style.format(2084)) does not fit the \(Int(yearFloor))pt year picker"
            )
            #expect(Self.controlChrome + Self.width(of: style.format(32)) <= yearFloor)
        }
    }

    @Test func monthGridColumnsFitThePopover() {
        let column = (Self.popoverContentWidth - 6 * 2) / 7
        for style in [MonthNameStyle.nepali, .transliterated] {
            for weekday in 1 ... 7 {
                let name = MonthGridModel.shortWeekdayName(weekday, style: style)
                #expect(Self.width(of: name) <= column, "'\(name)' needs ~\(Int(Self.width(of: name)))pt, column is \(Int(column))pt")
            }
        }
        for digits in [DigitScript.latin, .devanagari] {
            let day = digits.format(32)
            #expect(Self.width(of: day) * 1.5 <= column, "\(day) does not fit a \(Int(column))pt column")
        }
    }

    @Test func monthGridHeaderFitsThePopover() {
        let chevrons = 2 * Self.controlChrome
        let today = Self.controlChrome + 16 + Self.width(of: Strings.todayLabel)
        for style in [MonthNameStyle.nepali, .transliterated] {
            for month in 1 ... 12 {
                let title = "\(BikramSambatDate.monthName(month, style: style)) \(DigitScript.devanagari.format(2084))"
                let demanded = Self.width(of: title) * 1.2 + today + chevrons + 3 * 4
                #expect(demanded <= Self.popoverContentWidth, "'\(title)' header needs ~\(Int(demanded))pt")
            }
        }
    }

    private static func width(of string: String) -> CGFloat {
        let devanagariScalars = string.unicodeScalars.filter { (0x0900 ... 0x097F).contains($0.value) }.count
        let other = string.count - devanagariScalars
        return CGFloat(other) * 7.0 + CGFloat(devanagariScalars) * 9.0
    }
}
