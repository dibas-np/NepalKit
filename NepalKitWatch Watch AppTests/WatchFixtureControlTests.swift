// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKitWatchApp

@MainActor
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

        let dataset = CalendarDataset.v2
        let beforeInstant = try #require(before.instant)
        let beforeDay = try ResolvedDay(now: beforeInstant, in: dataset)
        #expect(beforeDay.bikramSambat == .beforeSupportedRange)

        let afterInstant = try #require(after.instant)
        let afterDay = try ResolvedDay(now: afterInstant, in: dataset)
        #expect(afterDay.bikramSambat == .afterSupportedRange)

        let terminalInstant = try #require(terminal.instant)
        let terminalToday = try #require(GregorianDate.today(now: terminalInstant))
        #expect(terminalToday.advanced(byDays: 13) == dataset.gregorianEnd)
    }

    @Test func unknownScenarioFailsClosed() {
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureScenario", "nonsense"]) == nil)
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureInstant", "not-a-date"]) == nil)
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureFailAt", "-1"]) == nil)
    }

    @Test func unknownPrefixedNameFailsClosed() {
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureUnknown", "value"]) == nil)
        #expect(WatchFixtureControl.fixture(arguments: [
            "-NepalKitFixtureScenario", "midnightApproach",
            "-NepalKitFixtureUnknown", "value",
        ]) == nil)
        #expect(WatchFixtureControl.fixture(arguments: [
            "-NepalKitFixtureUnknown", "value",
            "-NepalKitFixtureScenario", "midnightApproach",
        ]) == nil)
    }

    @Test func ordinaryArgumentsLeaveAValidFixtureIntact() throws {
        let fixture = try #require(WatchFixtureControl.fixture(arguments: [
            "-other", "args",
            "-NepalKitFixtureScenario", "midnightApproach",
            "--verbose",
        ]))
        #expect(fixture.instant == (try Date("2026-09-26T18:10:00Z", strategy: .iso8601)))
    }

    @Test func failureOffsetRequiresAFixedInstant() {
        #expect(WatchFixtureControl.fixture(arguments: ["-NepalKitFixtureFailAt", "3"]) == nil)
    }

    @Test func failureOffsetCanPrecedeTheFixedInstant() throws {
        let fixture = try #require(WatchFixtureControl.fixture(arguments: [
            "-NepalKitFixtureFailAt", "3",
            "-NepalKitFixtureInstant", "2026-09-26T18:30:00Z",
        ]))
        #expect(fixture.failAtHorizonOffset == 3)
        #expect(fixture.instant == (try Date("2026-09-26T18:30:00Z", strategy: .iso8601)))
    }

    @Test func failureOffsetCanUseAScenarioInstant() throws {
        let fixture = try #require(WatchFixtureControl.fixture(arguments: [
            "-NepalKitFixtureFailAt", "3",
            "-NepalKitFixtureScenario", "midnightApproach",
        ]))
        #expect(fixture.failAtHorizonOffset == 3)
        #expect(fixture.instant == (try Date("2026-09-26T18:10:00Z", strategy: .iso8601)))
    }

    @Test func fixtureModelRendersTheAfterBoundaryThroughProductionCode() async throws {
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
            "-NepalKitFixtureFailAt", "3",
            "-NepalKitFixtureInstant", "2026-09-26T18:30:00Z",
        ])
        let built = provider.timeline()

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
