// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if NEPALKIT_WATCH_FIXTURES
import Foundation
import NepalKitCore

struct WatchFixture: Sendable, Equatable {
    var instant: Date?

    var failAtHorizonOffset: Int?

    enum TodayError: Sendable, Equatable {
        case withContext
        case withoutContext
    }

    var todayError: TodayError?

    var failActivation: Bool

    nonisolated init() {
        self.instant = nil
        self.failAtHorizonOffset = nil
        self.todayError = nil
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
            guard let offset = Int(value) else { return false }
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
        case "today": fixture.todayError = .withContext
        case "withoutContext": fixture.todayError = .withoutContext
        default: return false
        }
        return true
    }

    nonisolated private static func scenarioInstant(_ name: String) -> Date? {
        if name == "midnightApproach" {
            return try? Date("2026-09-26T18:10:00Z", strategy: .iso8601)
        }
        let dataset = CalendarDataset.bundled
        let day: GregorianDate? = switch name {
        case "boundaryBefore": dataset.gregorianStart?.advanced(byDays: -1)
        case "boundaryAfter": dataset.gregorianEnd?.advanced(byDays: 1)
        case "projected2084": GregorianDate(BikramSambatDate(year: 2084, month: 6, day: 27), in: dataset)
        case "terminal": dataset.gregorianEnd?.advanced(byDays: -13)
        default: nil
        }
        return day?.noonUTC
    }
}

extension WatchFixtureControl {
    nonisolated static func clock(for fixture: WatchFixture) -> @Sendable () -> Date {
        guard let instant = fixture.instant else { return { Date.now } }
        let start = Date.now
        return { instant.addingTimeInterval(Date.now.timeIntervalSince(start)) }
    }

    nonisolated static func nextMidnight(for fixture: WatchFixture) -> @Sendable (Date) -> Date? {
        if fixture.failActivation {
            return { _ in nil }
        }
        return { TimeZone.nepal.nextMidnight(after: $0) }
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
