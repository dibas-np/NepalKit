// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import NepalKitWatchSupport

/// Sample states for previews, resolved through the dataset.
enum ComplicationSamples {
    /// 27 September 2026, 11 Ashoj 2083.
    static func supportedState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        let provider = TodayComplicationProvider(now: { .distantPast }, dataset: dataset)
        return provider.snapshot(isPreview: true).state
    }

    /// 13 April 2028, the first day past the dataset's end.
    static func boundaryState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        dayState(for: GregorianDate(year: 2028, month: 4, day: 13), in: dataset)
    }

    static func errorState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        .day(watchCalculationErrorDisplay(
            gregorianDay: GregorianDate(year: 2028, month: 4, day: 13),
            settings: .watch
        ))
    }

    static func errorWithoutContextState() -> TodayComplicationState {
        .day(watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch))
    }

    static func placeholderState() -> TodayComplicationState {
        .placeholder
    }

    /// Kartik, the widest month name, for checking corner and row fit.
    static func longestMonthState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        dayState(for: GregorianDate(year: 2026, month: 10, day: 20), in: dataset)
    }

    private static func dayState(for day: GregorianDate, in dataset: CalendarDataset) -> TodayComplicationState {
        .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
    }
}
