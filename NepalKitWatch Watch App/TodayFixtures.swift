// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if NEPALKIT_WATCH_FIXTURES
import Foundation
import NepalKitCore

/// Development-only fixture wiring for the Today screen. Compiled only under
/// `NEPALKIT_WATCH_FIXTURES`; a nondevelopment build contains none of it, so
/// no fixture route exists from the ordinary launch path.
enum TodayFixtures {
    /// What the fixture banner should say, or nil when no fixture is active.
    /// The banner is how an active fixture identifies itself on screen.
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
        guard !parts.isEmpty else { return nil }
        return "FIXTURE — " + parts.joined(separator: ", ")
    }

    /// The Today model wired to the fixture — the process launch arguments
    /// by default — or the ordinary model when no fixture is present.
    static func makeModel(arguments: [String] = ProcessInfo.processInfo.arguments) -> TodayModel {
        guard let fixture = WatchFixtureControl.fixture(arguments: arguments) else { return TodayModel() }
        let now: @Sendable () -> Date
        if let instant = fixture.instant {
            now = { instant }
        } else {
            now = { Date.now }
        }
        return TodayModel(
            now: now,
            resolveDay: { day, dataset in
                switch (fixture.failTodayWithContext, fixture.failTodayWithoutContext) {
                case (true, _):
                    throw DayResolutionError.datasetAssumptionFailure(day)
                case (_, true):
                    throw DayResolutionError.unreadableInstant(Date.now)
                default:
                    return try resolvedDay(for: day, in: dataset)
                }
            }
        )
    }
}
#endif
