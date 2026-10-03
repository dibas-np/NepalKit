// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// What `ComplicationAccessibility`'s label composition produces: the exact
/// wording for named argument combinations, the two boundary label shapes, the
/// error speech with and without resolved Gregorian context, and the canonical
/// month names — including their combining marks — through core-generated
/// samples.
///
/// **What this suite does not assert**, now stated plainly because it used to
/// imply otherwise: which family passes which flags. Every test here calls the
/// helper directly, so the correspondence between a family's visuals and its
/// announced label is not exercised here at all — a second test that made the
/// same call as its neighbour and asserted the same string was removed for
/// claiming a view behaviour it never touched. That correspondence is pinned by
/// `NepalKitTests/WatchPresentationWiringTests`, which derives it from each call
/// site in `TodayComplicationView.swift`.
///
/// No rendering assertion is attempted, deliberately: these are SwiftUI views,
/// and confirming the announced detail matches what is drawn needs either a
/// rendering harness this repository does not have or a third-party
/// view-inspection dependency `AGENTS.md` forbids without asking. The real check
/// is a device and a screen reader, recorded at
/// `docs/watch/physical-validation.md:57`.
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
                == "Sunday\n11 Ashoj 2083\n27 September 2026"
        )
    }

    @Test func compactFamiliesAnnounceTheFullBikramSambatDateWithoutGregorian() throws {
        let components = try supportedComponents

        // Circular, inline and corner show no weekday and no Gregorian date;
        // the announced year fills what the visuals omit.
        #expect(
            ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false)
                == "11 Ashoj 2083"
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
        #expect(ComplicationAccessibility.boundaryLabel(boundary, gregorian: true)
            == "Bikram Sambat unavailable, supported through 2084 BS\n13 April 2028")
    }

    @Test func errorLabelAnnouncesResolvedGregorianContextWithLatinDigits() {
        guard case .calculationError(let components) = watchCalculationErrorDisplay(
            gregorianDay: GADay(year: 2028, month: 4, day: 13),
            settings: .watch
        ) else {
            Issue.record("Expected an error display")
            return
        }

        #expect(components.spokenDescription == "Date calculation failed\n13 April 2028")
    }

    @Test func errorLabelWithoutContextSuppliesNoDate() {
        guard case .calculationError(let components) = watchCalculationErrorDisplay(
            gregorianDay: nil,
            settings: .watch
        ) else {
            Issue.record("Expected an error display")
            return
        }

        #expect(components.spokenDescription == "Date calculation failed")
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
