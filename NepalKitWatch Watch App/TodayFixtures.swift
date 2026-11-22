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
            parts.append("instant \(instant.formatted(.iso8601))")
        }
        if fixture.failAtHorizonOffset != nil {
            parts.append("timeline failure injection")
        }
        switch fixture.todayError {
        case .withContext: parts.append("today resolution failure")
        case .withoutContext: parts.append("today resolution failure without context")
        case nil: break
        }
        if fixture.failActivation {
            parts.append("midnight calculation failure")
        }
        guard !parts.isEmpty else { return nil }
        return "FIXTURE — " + parts.joined(separator: ", ")
    }

    static func makeModel(arguments: [String] = ProcessInfo.processInfo.arguments) -> TodayModel {
        guard let fixture = WatchFixtureControl.fixture(arguments: arguments) else { return TodayModel() }
        let clock = WatchFixtureControl.clock(for: fixture)
        return TodayModel(
            now: clock,
            nextMidnight: WatchFixtureControl.nextMidnight(for: fixture),
            displayFor: { _ in
                let instant = clock()
                return switch fixture.todayError {
                case .withContext:
                    watchCalculationErrorDisplay(gregorianDay: GregorianDate.today(now: instant), settings: .watch)
                case .withoutContext:
                    watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch)
                case nil:
                    watchDayDisplay(now: instant, settings: .watch, in: .bundled)
                }
            }
        )
    }
}
#endif
