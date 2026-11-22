// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import NepalKitWatchSupport

enum ComplicationSamples {
    static func supportedState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        let provider = TodayComplicationProvider(now: { .distantPast }, dataset: dataset)
        return provider.snapshot(isPreview: true).state
    }

    static func boundaryState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        guard let day = dayAfterSupportedRange(in: dataset) else { return .placeholder }
        return dayState(for: day, in: dataset)
    }

    static func errorState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        .day(watchCalculationErrorDisplay(gregorianDay: dayAfterSupportedRange(in: dataset), settings: .watch))
    }

    static func errorWithoutContextState() -> TodayComplicationState {
        .day(watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch))
    }

    static func placeholderState() -> TodayComplicationState {
        .placeholder
    }

    static func longestMonthState(in dataset: CalendarDataset = .v2) -> TodayComplicationState {
        guard let kartik = GregorianDate(BikramSambatDate(year: 2083, month: 7, day: 3), in: dataset) else { return .placeholder }
        return dayState(for: kartik, in: dataset)
    }

    private static func dayAfterSupportedRange(in dataset: CalendarDataset) -> GregorianDate? {
        dataset.gregorianEnd?.advanced(byDays: 1)
    }

    private static func dayState(for day: GregorianDate, in dataset: CalendarDataset) -> TodayComplicationState {
        .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
    }
}
