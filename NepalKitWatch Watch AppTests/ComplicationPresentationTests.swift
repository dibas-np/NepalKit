// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import NepalKitWatchSupport

/// Label wording only. Which family passes which flags is covered by
/// `NepalKitTests/WatchPresentationWiringTests`.
struct ComplicationPresentationTests {
    private let dataset = CalendarDataset.v2

    /// 27 September 2026 resolves to 11 Ashoj 2083, a Sunday.
    private var supportedComponents: WatchDayComponents {
        get throws {
            let day = try ResolvedDay(GregorianDate(year: 2026, month: 9, day: 27), in: dataset)
            guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
                throw DayResolutionError.datasetAssumptionFailure(GregorianDate(year: 2026, month: 9, day: 27))
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

        #expect(
            ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false)
                == "11 Ashoj 2083"
        )
    }

    // MARK: Boundary and error labels

    @Test func boundaryLabelRetainsTheSupportContext() throws {
        let day = try ResolvedDay(GregorianDate(year: 2028, month: 4, day: 13), in: dataset)
        guard case .rangeBoundary(let boundary) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a boundary display")
            return
        }

        #expect(ComplicationAccessibility.boundaryLabel(boundary) == "Bikram Sambat unavailable, supported through 2084 BS")
        #expect(ComplicationAccessibility.boundaryLabel(boundary, gregorian: true)
            == "Bikram Sambat unavailable, supported through 2084 BS\n13 April 2028")
    }

    @Test func errorLabelAnnouncesResolvedGregorianContextWithLatinDigits() {
        guard case .calculationError(let components) = watchCalculationErrorDisplay(
            gregorianDay: GregorianDate(year: 2028, month: 4, day: 13),
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
        // Kartik 1, 2083 is 18 October 2026.
        let kartikDay = try ResolvedDay(GregorianDate(year: 2026, month: 10, day: 18), in: dataset)
        guard case .supported(let components) = watchDayDisplay(for: kartikDay, settings: .watch, in: dataset) else {
            Issue.record("Expected a supported Kartik display")
            return
        }

        #expect(components.bikramSambatMonthName == "कात्तिक")
        #expect(BikramSambatDate.monthNames(style: .nepali).map { $0.count }.max() == "कात्तिक".count)
    }

    @Test func everyCanonicalMonthNameRendersThroughTheDisplayPath() throws {
        for (index, expected) in BikramSambatDate.monthNames(style: .nepali).enumerated() {
            let bsDay = BikramSambatDate(year: 2083, month: index + 1, day: 1)
            #expect(BikramSambatDate.monthName(bsDay.month, style: .nepali) == expected)
        }
    }
}
