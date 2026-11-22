// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if NEPALKIT_WATCH_FIXTURES
import Foundation
import NepalKitCore

struct WatchFixture: Sendable, Equatable {
    var instant: Date?

    var failAtHorizonOffset: Int?

    var failTodayWithContext: Bool?
    var failTodayWithoutContext: Bool?

    var failActivation: Bool

    nonisolated init() {
        self.instant = nil
        self.failAtHorizonOffset = nil
        self.failTodayWithContext = nil
        self.failTodayWithoutContext = nil
        self.failActivation = false
    }
}

enum WatchFixtureControl {
    nonisolated static var current: WatchFixture? {
        fixture(arguments: ProcessInfo.processInfo.arguments)
    }

    nonisolated static func fixture(arguments: [String]) -> WatchFixture? {
        guard arguments.contains(where: \.hasFixturePrefix) else { return nil }
        var fixture = WatchFixture()
        var index = 0
        while index < arguments.count {
            let option = arguments[index]
            guard option.hasFixturePrefix else {
                index += 1
                continue
            }
            if option == "-NepalKitFixtureFailActivation" {
                fixture.failActivation = true
                index += 1
                continue
            }
            guard let value = arguments.value(after: index),
                  apply(option, value, to: &fixture)
            else { return nil }
            index += 2
        }
        guard fixture.failAtHorizonOffset == nil || fixture.instant != nil else { return nil }
        return fixture
    }

    nonisolated private static func apply(_ option: String, _ value: String, to fixture: inout WatchFixture) -> Bool {
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
            return false
        }
        return true
    }

    nonisolated private static func applyError(_ value: String, to fixture: inout WatchFixture) -> Bool {
        switch value {
        case "today": fixture.failTodayWithContext = true
        case "withoutContext": fixture.failTodayWithoutContext = true
        default: return false
        }
        return true
    }

    nonisolated private static func scenarioInstant(_ name: String) -> Date? {
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

extension WatchFixtureControl {
    nonisolated static func clock(for fixture: WatchFixture) -> @Sendable () -> Date {
        guard let instant = fixture.instant else { return { Date.now } }
        return { instant }
    }
}

private extension String {
    nonisolated var hasFixturePrefix: Bool {
        hasPrefix("-NepalKitFixture")
    }
}

private extension [String] {
    nonisolated func value(after index: Int) -> String? {
        guard index + 1 < count, !self[index + 1].hasPrefix("-") else { return nil }
        return self[index + 1]
    }
}
#endif
