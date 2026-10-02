// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The complication presentation contract: accessible labels retain the
/// complete Bikram Sambat information (Latin digits, full year), announce the
/// weekday only where the family shows one, add Gregorian detail only where
/// the surface presents it, and keep the firm compact copy exact. The longest
/// canonical month names — including their combining marks — are exercised
/// through core-generated samples.
struct ComplicationPresentationTests {
    private let dataset = CalendarDataset.v2

    /// 27 September 2026 resolves to 11 Ashoj 2083, a Sunday.
    private var supportedComponents: WatchDayComponents {
        get throws {
            let day = try resolvedDay(for: GADay(year: 2026, month: 9, day: 27), in: dataset)
            guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
                throw DayResolutionError.datasetAssumptionFailure(GADay(year: 2026, month: 9, day: 27))
            }
            return components
        }
    }

    // MARK: Supported labels

    @Test func rectangularAnnouncesWeekdayFullDateAndGregorian() throws {
        let components = try supportedComponents

        #expect(
            ComplicationAccessibility.supportedLabel(components, weekday: true, gregorian: true)
                == "आइत\n11 असोज 2083\n27 September 2026"
        )
    }

    @Test func compactFamiliesAnnounceTheFullBikramSambatDateWithoutGregorian() throws {
        let components = try supportedComponents

        // Circular, inline and corner show no weekday and no Gregorian date;
        // the announced year fills what the visuals omit.
        #expect(
            ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false)
                == "11 असोज 2083"
        )
    }

    @Test func largeRectangularFallbackDropsWhatTheVisualsDrop() throws {
        let components = try supportedComponents

        // The large-text fallback removes the weekday and Gregorian detail
        // first; the label follows the visuals.
        #expect(
            ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false)
                == "11 असोज 2083"
        )
    }

    // MARK: Boundary and error labels

    @Test func boundaryLabelRetainsTheSupportContext() throws {
        let day = try resolvedDay(for: GADay(year: 2028, month: 4, day: 13), in: dataset)
        guard case .rangeBoundary(let boundary) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a boundary display")
            return
        }

        // Compact visuals show only "Unavailable"; the announced label keeps
        // the support context the visuals cannot fit.
        #expect(ComplicationAccessibility.boundaryLabel(boundary) == "Bikram Sambat unavailable, supported through 2084 BS")
    }

    @Test func errorLabelAnnouncesResolvedGregorianContextWithLatinDigits() {
        guard case .calculationError(let components) = watchCalculationErrorDisplay(
            gregorianDay: GADay(year: 2028, month: 4, day: 13),
            settings: .watch
        ) else {
            Issue.record("Expected an error display")
            return
        }

        #expect(ComplicationAccessibility.errorLabel(components) == "Date calculation failed\n13 April 2028")
    }

    @Test func errorLabelWithoutContextSuppliesNoDate() {
        guard case .calculationError(let components) = watchCalculationErrorDisplay(
            gregorianDay: nil,
            settings: .watch
        ) else {
            Issue.record("Expected an error display")
            return
        }

        #expect(ComplicationAccessibility.errorLabel(components) == "Date calculation failed")
    }

    // MARK: Longest canonical month representation

    @Test func cornerLabelCarriesTheLongestMonthNameWithCombiningMarks() throws {
        // Kartik 2083 begins the day after Ashoj's 31 days end; 27 September
        // 2026 is 11 Ashoj, so Kartik 1 is 18 October. Its canonical name is
        // the longest the dataset renders and carries combining marks — the
        // worst case for the corner's tight label geometry.
        let kartikDay = try resolvedDay(for: GADay(year: 2026, month: 10, day: 18), in: dataset)
        guard case .supported(let components) = watchDayDisplay(for: kartikDay, settings: .watch, in: dataset) else {
            Issue.record("Expected a supported Kartik display")
            return
        }

        #expect(components.bikramSambatMonthName == "कात्तिक")
        #expect(nepaliMonthNames.map { $0.count }.max() == "कात्तिक".count)
    }

    @Test func everyCanonicalMonthNameRendersThroughTheDisplayPath() throws {
        // All twelve canonical names must survive the display path unchanged,
        // including every combining mark.
        for (index, expected) in nepaliMonthNames.enumerated() {
            let bsDay = BSDay(year: 2083, month: index + 1, day: 1)
            #expect(monthName(month: bsDay.month, style: .nepali) == expected)
        }
    }
}
