// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The Watch display contract: core supplies the complete meaning of a
/// resolved day — components, firm state copy and independent speech — so the
/// app and the extension cannot drift. Views compose and lay out; they never
/// resolve dates or format numbers themselves.
struct WatchDayDisplayTests {
    private let dataset = CalendarDataset.v2

    // MARK: Supported days

    @Test func supportedComponentsCarryTheCanonicalPresentation() throws {
        // 27 September 2026 NPT = 11 Ashoj 2083, a Sunday.
        let day = try resolvedDay(for: GADay(year: 2026, month: 9, day: 27), in: dataset)

        guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a supported display")
            return
        }

        #expect(components.weekdayName == "आइत")
        #expect(components.bikramSambatDay == "११")
        #expect(components.bikramSambatMonthName == "असोज")
        #expect(components.bikramSambatYear == "२०८३")
        #expect(components.gregorianDay == "२७")
        #expect(components.gregorianMonthName == "September")
        #expect(components.gregorianYear == "२०२६")
    }

    @Test func supportedSpeechIsIndependentAndComplete() throws {
        let day = try resolvedDay(for: GADay(year: 2026, month: 9, day: 27), in: dataset)

        guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a supported display")
            return
        }

        // Speech uses Latin digits, canonical Nepali names, and the complete
        // year — whatever the visuals render.
        #expect(components.spokenBikramSambat == "11 असोज 2083")
        #expect(components.spokenWeekdayName == "आइत")
        #expect(components.spokenGregorian == "27 September 2026")
    }

    @Test func supportedComponentsHonorOtherFixedSettings() throws {
        // The builder takes settings rather than hard-coding the Watch's, so a
        // transliterated/Latin combination renders through the same contract.
        let day = try resolvedDay(for: GADay(year: 2026, month: 9, day: 27), in: dataset)

        guard case .supported(let components) = watchDayDisplay(
            for: day,
            settings: DisplaySettings(digits: .latin, monthNames: .transliterated),
            in: dataset
        ) else {
            Issue.record("Expected a supported display")
            return
        }

        #expect(components.weekdayName == "Sunday")
        #expect(components.bikramSambatDay == "11")
        #expect(components.bikramSambatMonthName == "Ashoj")
        #expect(components.gregorianYear == "2026")
        #expect(components.spokenBikramSambat == "11 Ashoj 2083")
    }

    // MARK: Range boundaries

    @Test func beforeBoundaryNamesTheFirstSupportedYear() throws {
        let day = try resolvedDay(for: GADay(year: 1918, month: 4, day: 12), in: dataset)

        guard case .rangeBoundary(let boundary) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a range boundary display")
            return
        }

        #expect(boundary.side == .before)
        #expect(boundary.contextYear == "१९७५")
        #expect(boundary.contextLine == "Supported from १९७५ BS")
        #expect(boundary.gregorianDay == "१२")
        #expect(boundary.gregorianMonthName == "April")
        #expect(boundary.gregorianYear == "१९१८")
        #expect(boundary.spokenDescription == "Bikram Sambat unavailable, supported from 1975 BS")
    }

    @Test func afterBoundaryNamesTheLastSupportedYear() throws {
        let day = try resolvedDay(for: GADay(year: 2028, month: 4, day: 13), in: dataset)

        guard case .rangeBoundary(let boundary) = watchDayDisplay(for: day, settings: .watch, in: dataset) else {
            Issue.record("Expected a range boundary display")
            return
        }

        #expect(boundary.side == .after)
        #expect(boundary.contextYear == "२०८४")
        #expect(boundary.contextLine == "Supported through २०८४ BS")
        #expect(boundary.gregorianDay == "१३")
        #expect(boundary.gregorianMonthName == "April")
        #expect(boundary.gregorianYear == "२०२८")
        #expect(boundary.spokenDescription == "Bikram Sambat unavailable, supported through 2084 BS")
    }

    @Test func firmStateCopyIsExact() {
        // The accepted presentation fixes this copy; a drift here changes what
        // users are told on every surface at once.
        #expect(WatchDayCopy.boundaryFull == "Bikram Sambat unavailable")
        #expect(WatchDayCopy.boundaryCompact == "Unavailable")
        #expect(WatchDayCopy.failureFull == "Date calculation failed")
        #expect(WatchDayCopy.failureCompact == "Error")
    }

    // MARK: Calculation errors

    @Test func calculationErrorCarriesResolvedGregorianContext() {
        let display = watchCalculationErrorDisplay(
            gregorianDay: GADay(year: 2028, month: 4, day: 13),
            settings: .watch
        )

        guard case .calculationError(let components) = display else {
            Issue.record("Expected a calculation error display")
            return
        }

        #expect(components.gregorianDay == "१३")
        #expect(components.gregorianMonthName == "April")
        #expect(components.gregorianYear == "२०२८")
    }

    @Test func calculationErrorWithoutResolvedContextSuppliesNoDate() {
        let display = watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch)

        guard case .calculationError(let components) = display else {
            Issue.record("Expected a calculation error display")
            return
        }

        // An error without a resolved Gregorian day invents nothing.
        #expect(components.gregorianDay == nil)
        #expect(components.gregorianMonthName == nil)
        #expect(components.gregorianYear == nil)
    }
}
