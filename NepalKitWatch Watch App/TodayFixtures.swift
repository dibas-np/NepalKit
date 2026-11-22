// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if NEPALKIT_WATCH_FIXTURES
import Foundation
import NepalKitCore
import NepalKitWatchSupport

enum TodayFixtures {
    static var bannerNote: String? {
        guard let fixture = WatchFixtureControl.current else { return nil }
        var parts: [String] = []
        if let instant = fixture.instant {
            parts.append("instant \(instant.formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false))))")
        }
        if fixture.failAtHorizonOffset != nil {
            parts.append("timeline failure injection")
        }
        if fixture.failTodayWithContext == true {
            parts.append("today resolution failure")
        }
        if fixture.failTodayWithoutContext == true {
            parts.append("today resolution failure without context")
        }
        if fixture.failActivation {
            parts.append("midnight calculation failure")
        }
        guard !parts.isEmpty else { return nil }
        return "FIXTURE — " + parts.joined(separator: ", ")
    }

    static func makeModel(arguments: [String] = ProcessInfo.processInfo.arguments) -> TodayModel {
        guard let fixture = WatchFixtureControl.fixture(arguments: arguments) else { return TodayModel() }
        let nextMidnight: @Sendable (Date) -> Date?
        if fixture.failActivation {
            nextMidnight = { _ in nil }
        } else {
            nextMidnight = { TimeZone.nepal.nextMidnight(after: $0) }
        }
        return TodayModel(
            now: WatchFixtureControl.clock(for: fixture),
            nextMidnight: nextMidnight,
            displayFor: { instant in
                switch (fixture.failTodayWithContext, fixture.failTodayWithoutContext) {
                case (true, _):
                    return watchCalculationErrorDisplay(gregorianDay: GregorianDate.today(now: instant), settings: .watch)
                case (_, true):
                    return watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch)
                default:
                    return watchDayDisplay(now: instant, settings: .watch, in: CalendarDataset.v2)
                }
            }
        )
    }
}
#endif
