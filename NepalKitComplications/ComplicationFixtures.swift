// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Development-only identification for fixture-built complications. Always
/// compiled so views can reference it; the marker is empty in every
/// nondevelopment build.
enum ComplicationFixtureMarker {
    static var suffix: String {
        #if NEPALKIT_WATCH_FIXTURES
        WatchFixtureControl.current != nil ? " · fixture" : ""
        #else
        ""
        #endif
    }
}

#if NEPALKIT_WATCH_FIXTURES
/// Development-only fixture wiring for the complication extension. Compiled
/// only under `NEPALKIT_WATCH_FIXTURES`; a nondevelopment build contains none
/// of it, so `TodayComplication` simply constructs the ordinary provider.
///
/// The fixture's fixed instant and timeline failure injection flow through
/// the production builder's seams. The selected instant is identifiable in
/// the rendered complications by its pinned date and, where the family has
/// room, by the fixture marker; the Today screen carries the explicit fixture
/// banner for the paired app process.
enum ComplicationFixtures {
    /// The provider wired to the fixture — the process launch arguments by
    /// default — or the ordinary provider when no fixture is present.
    nonisolated static func makeProvider(arguments: [String] = ProcessInfo.processInfo.arguments) -> TodayComplicationProvider {
        guard let fixture = WatchFixtureControl.fixture(arguments: arguments) else {
            return TodayComplicationProvider()
        }
        return provider(for: fixture)
    }

    nonisolated private static func provider(for fixture: WatchFixture) -> TodayComplicationProvider {
        let dataset = CalendarDataset.v2
        let nextMidnight: @Sendable (Date) -> Date?
        if fixture.failActivation {
            nextMidnight = { _ in nil }
        } else {
            nextMidnight = { nextNPTMidnight(after: $0) }
        }
        return TodayComplicationProvider(
            now: WatchFixtureControl.clock(for: fixture),
            dataset: dataset,
            makeBuilder: { builder(for: fixture, dataset: dataset, nextMidnight: nextMidnight) }
        )
    }

    nonisolated private static func builder(
        for fixture: WatchFixture,
        dataset: CalendarDataset,
        nextMidnight: @escaping @Sendable (Date) -> Date?
    ) -> TodayTimelineBuilder {
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
            nextMidnight: nextMidnight
        )
    }
}
#endif
