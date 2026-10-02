// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if NEPALKIT_WATCH_FIXTURES
import Foundation
import NepalKitCore

/// Development-only fixture control for the Watch targets.
///
/// Everything in this file compiles only when `NEPALKIT_WATCH_FIXTURES` is in
/// `SWIFT_ACTIVE_COMPILATION_CONDITIONS` — set on the Watch targets' Debug
/// configurations, absent from Release. Nondevelopment builds contain no
/// fixture symbols and no reachable fixture entry point: the factories that
/// consume this control are themselves inside the same condition, and the
/// launch arguments it reads are inert without it.
///
/// The control reads launch arguments (`ProcessInfo.processInfo.arguments`),
/// so a fixture choice lives for one launch only — there is no settings entry
/// point, no persistence, and the system clock is never changed. It selects
/// inputs and failure points for the production resolver, timeline builder
/// and views; it never supplies calendar answers, maintains a table, or
/// hand-maintains a paired date. To return to ordinary mode for a real
/// Nepal-midnight observation, build without the condition (Release, or
/// remove it from the Debug configuration) and relaunch without arguments.
///
/// Launch arguments:
///
///     -NepalKitFixtureInstant <ISO-8601 instant with Z>
///     -NepalKitFixtureScenario <boundaryBefore|boundaryAfter|projected2084|
///                               terminal|midnightApproach>
///     -NepalKitFixtureFailAt <horizon offset, e.g. 3>
///     -NepalKitFixtureError <today|withoutContext>
///
/// Scenario instants are inputs, not display pairs: production code renders
/// whatever the shared dataset resolves for them.
struct WatchFixture: Sendable, Equatable {
    /// The fixed instant the injected clock returns, replacing the wall-clock
    /// read. nil leaves the clock ordinary.
    var instant: Date?

    /// The horizon offset (0 = today) whose day resolution fails, for
    /// exercising prefix retention and the error reload policy. The failed
    /// day keeps its Gregorian context.
    var failAtHorizonOffset: Int?

    /// Injects a resolution failure for Today itself: `true` keeps the
    /// derived Gregorian context, `false` throws the context-less case.
    var failTodayWithContext: Bool?
    var failTodayWithoutContext: Bool?
}

enum WatchFixtureControl {
    /// The launch arguments of the current process.
    static var current: WatchFixture? {
        fixture(arguments: ProcessInfo.processInfo.arguments)
    }

    /// Parses the fixture launch arguments, or nil when none are present.
    /// Unknown names and values fail closed: the fixture is ignored rather
    /// than half-applied.
    static func fixture(arguments: [String]) -> WatchFixture? {
        guard arguments.contains(where: \.hasFixturePrefix) else { return nil }
        var fixture = WatchFixture()
        var index = 0
        while index < arguments.count {
            let option = arguments[index]
            guard option.hasFixturePrefix else {
                index += 1
                continue
            }
            guard let value = arguments.value(after: index),
                  apply(option, value, to: &fixture)
            else { return nil }
            index += 2
        }
        return fixture
    }

    /// Applies one fixture option and its value. Returns false when the
    /// option is a fixture option whose value cannot be honored — the whole
    /// fixture then fails closed.
    private static func apply(_ option: String, _ value: String, to fixture: inout WatchFixture) -> Bool {
        switch option {
        case "-NepalKitFixtureInstant":
            guard let instant = try? Date(value, strategy: .iso8601) else { return false }
            fixture.instant = instant
        case "-NepalKitFixtureScenario":
            guard let instant = scenarioInstant(value) else { return false }
            fixture.instant = instant
        case "-NepalKitFixtureFailAt":
            guard let offset = Int(value), offset >= 0 else { return false }
            fixture.failAtHorizonOffset = offset
        case "-NepalKitFixtureError":
            guard applyError(value, to: &fixture) else { return false }
        default:
            // An unrecognized fixture-prefixed argument is inert.
            break
        }
        return true
    }

    private static func applyError(_ value: String, to fixture: inout WatchFixture) -> Bool {
        switch value {
        case "today": fixture.failTodayWithContext = true
        case "withoutContext": fixture.failTodayWithoutContext = true
        default: return false
        }
        return true
    }

    /// The named scenario instants. Each is a harness input chosen to place
    /// production code in the named situation — a day before the range, a day
    /// after it, inside the provisional 2084 year, on the day whose horizon
    /// ends at the dataset maximum, and minutes before a Nepal midnight.
    private static func scenarioInstant(_ name: String) -> Date? {
        switch name {
        case "boundaryBefore": try? Date("1918-04-12T06:15:00Z", strategy: .iso8601)
        case "boundaryAfter": try? Date("2028-04-13T06:15:00Z", strategy: .iso8601)
        case "projected2084": try? Date("2027-10-14T06:15:00Z", strategy: .iso8601)
        case "terminal": try? Date("2028-03-30T06:15:00Z", strategy: .iso8601)
        case "midnightApproach": try? Date("2026-09-26T18:10:00Z", strategy: .iso8601)
        default: nil
        }
    }
}

private extension String {
    var hasFixturePrefix: Bool {
        hasPrefix("-NepalKitFixture")
    }
}

private extension [String] {
    /// The argument after the option at `index`, when present and not itself
    /// an option.
    func value(after index: Int) -> String? {
        guard index + 1 < count, !self[index + 1].hasPrefix("-") else { return nil }
        return self[index + 1]
    }
}
#endif
