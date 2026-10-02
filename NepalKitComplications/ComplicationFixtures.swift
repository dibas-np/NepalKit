// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if NEPALKIT_WATCH_FIXTURES
import Foundation
import NepalKitCore

/// Development-only fixture wiring for the complication extension. Compiled
/// only under `NEPALKIT_WATCH_FIXTURES`; a nondevelopment build contains none
/// of it, so `TodayComplication` simply constructs the ordinary provider.
///
/// The fixture's fixed instant and timeline failure injection flow through
/// the production builder's seams. The selected instant is identifiable in
/// the rendered complications by its pinned date; the Today screen carries
/// the explicit fixture banner for the paired app process.
enum ComplicationFixtures {
    /// The provider wired to the fixture — the process launch arguments by
    /// default — or the ordinary provider when no fixture is present.
    static func makeProvider(arguments: [String] = ProcessInfo.processInfo.arguments) -> TodayComplicationProvider {
        guard let fixture = WatchFixtureControl.fixture(arguments: arguments) else {
            return TodayComplicationProvider()
        }
        let dataset = CalendarDataset.v2
        let now: @Sendable () -> Date
        if let instant = fixture.instant {
            now = { instant }
        } else {
            now = { Date.now }
        }
        return TodayComplicationProvider(now: now, dataset: dataset, makeBuilder: {
            let today = fixture.instant.flatMap { todayAD(now: $0) }
            let failDay = fixture.failAtHorizonOffset.flatMap { offset in
                today.flatMap { $0.advanced(byDays: offset) }
            }
            return TodayTimelineBuilder(
                dataset: dataset,
                resolveDay: { day in
                    if let failDay, day == failDay {
                        throw DayResolutionError.datasetAssumptionFailure(day)
                    }
                    return try resolvedDay(for: day, in: dataset)
                },
                nextMidnight: { nextNPTMidnight(after: $0) }
            )
        })
    }
}
#endif
