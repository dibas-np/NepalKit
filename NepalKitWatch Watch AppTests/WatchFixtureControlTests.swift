// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKitWatchApp

/// The development fixture harness: it parses its launch arguments exactly,
/// fails closed on anything it does not fully understand, and drives the
/// production seams — fixed instants through the clock, failure points
/// through the resolver — without changing any calendar answer. Every symbol
/// here exists only when NEPALKIT_WATCH_FIXTURES compiles in.
struct WatchFixtureControlTests {
    @Test func noFixtureArgumentsYieldNoFixture() {
        #expect(WatchFixtureControl.fixture(arguments: []) == nil)
        #expect(WatchFixtureControl.fixture(arguments: ["-other", "args"]) == nil)
    }

    @Test func explicitInstantParsesAsISO8601() throws {
        let fixture = try #require(
            WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureInstant", "2084-06-01T06:15:00Z"])
        )
        let expected = try Date("2084-06-01T06:15:00Z", strategy: .iso8601)
        #expect(fixture.instant == expected)
    }

    @Test func namedScenariosResolveTheirInstants() throws {
        let before = try #require(
            WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureScenario", "boundaryBefore"])
        )
        let after = try #require(
            WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureScenario", "boundaryAfter"])
        )
        let terminal = try #require(
            WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureScenario", "terminal"])
        )

        // The scenario instants must place production code on the intended
        // sides of the dataset's exact bounds.
        let dataset = CalendarDataset.v2
        let beforeInstant = try #require(before.instant)
        let beforeDay = try resolvedDay(now: beforeInstant, in: dataset)
        #expect(beforeDay.bikramSambat == .beforeSupportedRange)

        let afterInstant = try #require(after.instant)
        let afterDay = try resolvedDay(now: afterInstant, in: dataset)
        #expect(afterDay.bikramSambat == .afterSupportedRange)

        // The terminal scenario's day +13 is the dataset maximum, which the
        // timeline contract answers with the conditional fifteenth entry.
        let terminalInstant = try #require(terminal.instant)
        let terminalToday = try #require(todayAD(now: terminalInstant))
        #expect(terminalToday.advanced(byDays: 13) == dataset.gregorianEnd)
    }

    @Test func unknownScenarioFailsClosed() {
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureScenario", "nonsense"]) == nil)
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureInstant", "not-a-date"]) == nil)
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureFailAt", "-1"]) == nil)
    }

    // MARK: The harness exercises production paths

    @Test func fixtureModelRendersTheAfterBoundaryThroughProductionCode() async throws {
        // The arguments flow through the app module's own parsing and wiring.
        let model = TodayFixtures.makeModel(arguments: ["-NepalKitFixtureScenario", "boundaryAfter"])
        model.activate()

        guard case .rangeBoundary(let boundary) = model.display else {
            Issue.record("Expected the fixture instant to render the after boundary")
            return
        }
        #expect(boundary.side == .after)
        model.deactivate()
    }

    @Test func fixtureProviderInjectsTheTimelineFailureAtTheRequestedOffset() throws {
        let provider = ComplicationFixtures.makeProvider(arguments: [
            "-NepalKitFixtureInstant", "2026-09-26T18:30:00Z",
            "-NepalKitFixtureFailAt", "3",
        ])
        let built = provider.timeline()

        // The valid prefix survives; the injected failure lands at day +3's
        // intended activation and construction stops.
        #expect(built.entries.count == 4)
        #expect(try built.entries[3].date == UTCWatchFixture.utc(2026, 9, 29, 18, 15))
        guard case .day(.calculationError(let components)) = built.entries[3].state else {
            Issue.record("Expected the injected failure to render as a calculation error")
            return
        }
        #expect(components.gregorianDay == "३०")
        #expect(built.policy == .after(built.entries[3].date.addingTimeInterval(15 * 60)))
    }
}
