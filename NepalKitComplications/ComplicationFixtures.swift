// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

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
enum ComplicationFixtures {
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
            nextMidnight = { TimeZone.nepal.nextMidnight(after: $0) }
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
        let today = fixture.instant.flatMap { GregorianDate.today(now: $0) }
        let failDay = fixture.failAtHorizonOffset.flatMap { offset in
            today.flatMap { $0.advanced(byDays: offset) }
        }
        return TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { day in
                if let failDay, day == failDay {
                    throw DayResolutionError.datasetAssumptionFailure(day)
                }
                return try ResolvedDay(day, in: dataset)
            },
            nextMidnight: nextMidnight
        )
    }
}
#endif
