// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Core-generated states for previews and the development harness. Every
/// sample resolves through the shared dataset — nothing here hand-maintains
/// a paired date, so a table change moves the samples with it.
enum ComplicationSamples {
    /// The supported sample: 27 September 2026, 11 Ashoj 2083 — the same
    /// anchored day the provider's preview snapshot renders.
    static func supportedState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        let provider = TodayComplicationProvider(now: { .distantPast }, dataset: dataset)
        return provider.snapshot(isPreview: true).state
    }

    /// The after-maximum boundary sample: 13 April 2028, the first day past
    /// the dataset's Gregorian end.
    static func boundaryState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        dayState(for: GADay(year: 2028, month: 4, day: 13), in: dataset)
    }

    /// The calculation-failure sample, with the failed day resolved as
    /// Gregorian context.
    static func errorState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        .day(watchCalculationErrorDisplay(
            gregorianDay: GADay(year: 2028, month: 4, day: 13),
            settings: .watch
        ))
    }

    /// The calculation-failure sample without any resolved Gregorian day.
    static func errorWithoutContextState() -> TodayComplicationState {
        .day(watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch))
    }

    /// The clock-free placeholder sample.
    static func placeholderState() -> TodayComplicationState {
        .placeholder
    }

    /// The worst-case month sample: Kartik, the longest canonical name with
    /// combining marks. Kartik does not occur naturally until 18 October
    /// 2026, and the on-device fixture harness cannot reach the extension
    /// process, so the curved-label and row-width fit is judged through
    /// previews until then.
    static func longestMonthState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        dayState(for: GADay(year: 2026, month: 10, day: 20), in: dataset)
    }

    private static func dayState(for day: GADay, in dataset: CalendarDataset) -> TodayComplicationState {
        .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
    }
}
