// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import WidgetKit

/// The timeline builder contract: one clock reading anchors entry zero;
/// future entries activate at successive Nepal midnights (only future-midnight
/// intervals are twenty-four hours apart); every day resolves independently,
/// boundaries included; the conditional terminal entry appears only when day
/// +13 is the dataset maximum; and calculation failures retain the prefix,
/// stop construction, and select the fifteen-minute `.after` request while
/// successful timelines — boundary entries included — use `.atEnd`.
///
/// Failures are pinned through the builder's resolver and midnight seams, the
/// same injection points the development harness uses; the production wiring
/// under test is the default closure set the provider installs.
struct TodayTimelineBuilderTests {
    private let dataset = CalendarDataset.v2

    // Anchored instant: 26 Sep 2026, 18:30 UTC = 00:15 NPT on 27 Sep, so
    // day 0 is 2026-09-27 (11 Ashoj 2083) and day k's midnight begins at
    // 2026-09-26 18:15 UTC + k days.
    private func supportedNow() throws -> Date {
        try UTCWatchFixture.utc(2026, 9, 26, 18, 30)
    }

    private var builder: TodayTimelineBuilder {
        TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { try resolvedDay(for: $0, in: self.dataset) },
            nextMidnight: { nextNPTMidnight(after: $0) }
        )
    }

    // MARK: The successful horizon

    @Test func successfulTimelineHasFourteenEntriesAndAtEnd() throws {
        let built = builder.build(now: try supportedNow())

        #expect(built.entries.count == 14)
        #expect(built.policy == .atEnd)
    }

    @Test func entryZeroActivatesAtTheOriginalReading() throws {
        let now = try supportedNow()
        let built = builder.build(now: now)

        #expect(built.entries[0].date == now)
    }

    @Test func futureEntriesActivateAtSuccessiveNepalMidnights() throws {
        let built = builder.build(now: try supportedNow())

        // Day 1 begins at 00:00 NPT on 28 Sep = 27 Sep 18:15 UTC.
        #expect(try built.entries[1].date == UTCWatchFixture.utc(2026, 9, 27, 18, 15))
        #expect(try built.entries[2].date == UTCWatchFixture.utc(2026, 9, 28, 18, 15))
        #expect(try built.entries[13].date == UTCWatchFixture.utc(2026, 10, 9, 18, 15))
    }

    @Test func onlyFutureEntriesAreTwentyFourHoursApart() throws {
        let built = builder.build(now: try supportedNow())

        // The first interval varies (here 23h45m); every future-midnight
        // interval is exactly one civil day.
        #expect(built.entries[1].date.timeIntervalSince(built.entries[0].date) != 86_400)
        for index in 1 ..< built.entries.count - 1 {
            let spacing = built.entries[index + 1].date.timeIntervalSince(built.entries[index].date)
            #expect(spacing == 86_400)
        }
    }

    @Test func everyEntryCarriesItsResolvedDayInOrder() throws {
        let built = builder.build(now: try supportedNow())

        // Day 0 is 11 Ashoj 2083; each later entry advances one Gregorian day.
        guard case .day(.supported(let first)) = built.entries[0].state else {
            Issue.record("Expected a supported entry zero")
            return
        }
        #expect(first.bikramSambatDay == "११")
        guard case .day(.supported(let last)) = built.entries[13].state else {
            Issue.record("Expected a supported final entry")
            return
        }
        // Day +13 = 10 October 2026 = २४ असोज २०८३ (11 Ashoj + 13 days).
        #expect(last.gregorianDay == "१०")
        #expect(last.gregorianMonthName == "October")
        #expect(last.bikramSambatDay == "२४")
    }

    // MARK: Boundaries inside the horizon

    @Test func beforeMinimumTodayEntersSupport() throws {
        // 10 April 1918 NPT: days 0–2 are before the range; day 3 is
        // 13 April 1918, 1 Baisakh 1975.
        let now = try UTCWatchFixture.utc(1918, 4, 10, 12, 0)
        let built = builder.build(now: now)

        #expect(built.entries.count == 14)
        #expect(built.policy == .atEnd)
        for index in 0 ... 2 {
            guard case .day(.rangeBoundary(let boundary)) = built.entries[index].state else {
                Issue.record("Expected a boundary entry at offset \(index)")
                return
            }
            #expect(boundary.side == .before)
        }
        guard case .day(.supported(let entering)) = built.entries[3].state else {
            Issue.record("Expected the horizon to enter support at offset 3")
            return
        }
        #expect(entering.bikramSambatDay == "१")
        #expect(entering.bikramSambatMonthName == "बैशाख")
    }

    @Test func afterMaximumTodayProgressesThroughTheHorizon() throws {
        // 13 April 2028 NPT: every entry is an after-boundary and Gregorian
        // days still progress; no terminal entry is appended because the
        // maximum is behind Today.
        let now = try UTCWatchFixture.utc(2028, 4, 13, 12, 0)
        let built = builder.build(now: now)

        #expect(built.entries.count == 14)
        #expect(built.policy == .atEnd)
        for index in 0 ... 13 {
            guard case .day(.rangeBoundary(let boundary)) = built.entries[index].state else {
                Issue.record("Expected a boundary entry at offset \(index)")
                return
            }
            #expect(boundary.side == .after)
        }
        guard case .day(.rangeBoundary(let last)) = built.entries[13].state else {
            Issue.record("Expected a boundary final entry")
            return
        }
        // Day +13 = 26 April 2028; the Gregorian date remains answerable.
        #expect(last.gregorianDay == "२६")
        #expect(last.gregorianMonthName == "April")
    }

    @Test func maximumEarlierInTheHorizonDoesNotDuplicateTheBoundary() throws {
        // 7 April 2028 NPT: the maximum (12 April) is day +5, so day +6
        // (13 April) is the horizon's own boundary and no terminal entry is
        // appended.
        let now = try UTCWatchFixture.utc(2028, 4, 7, 12, 0)
        let built = builder.build(now: now)

        #expect(built.entries.count == 14)
        #expect(built.policy == .atEnd)
        let boundaryCount = built.entries.filter {
            if case .day(.rangeBoundary) = $0.state { return true }
            return false
        }.count
        #expect(boundaryCount == 8)
    }

    @Test func maximumExactlyAtDayPlusThirteenAppendsTheTerminalBoundary() throws {
        // 30 March 2028 NPT: day +13 is 12 April 2028, the dataset maximum,
        // so exactly one boundary entry is appended at day +14's midnight.
        let now = try UTCWatchFixture.utc(2028, 3, 30, 12, 0)
        let built = builder.build(now: now)

        #expect(built.entries.count == 15)
        #expect(built.policy == .atEnd)
        #expect(try built.entries[13].date == UTCWatchFixture.utc(2028, 4, 11, 18, 15))
        #expect(try built.entries[14].date == UTCWatchFixture.utc(2028, 4, 12, 18, 15))
        guard case .day(.rangeBoundary(let terminal)) = built.entries[14].state else {
            Issue.record("Expected the terminal entry to be the range boundary")
            return
        }
        #expect(terminal.side == .after)
    }

    // MARK: Calculation failures

    @Test func firstDayFailureAppendsOneErrorAtTheOriginalReadingAndStops() throws {
        let now = try supportedNow()
        let calls = CallCounter()
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { _ in calls.increment(); throw DayResolutionError.datasetAssumptionFailure(GADay(year: 2026, month: 9, day: 27)) },
            nextMidnight: { nextNPTMidnight(after: $0) }
        )

        let built = failing.build(now: now)

        #expect(built.entries.count == 1)
        #expect(built.entries[0].date == now)
        guard case .day(.calculationError(let components)) = built.entries[0].state else {
            Issue.record("Expected a calculation error entry")
            return
        }
        // The NPT day was derived, so the error carries it as context.
        #expect(components.gregorianDay == "२७")
        #expect(components.gregorianMonthName == "September")
        #expect(calls.value == 1)
        assertErrorPolicy(built, retryAt: now.addingTimeInterval(15 * 60))
    }

    @Test func intermediateFailureRetainsThePrefixAndStops() throws {
        // Day +3 is 30 September 2026; fail exactly there.
        let failedDay = GADay(year: 2026, month: 9, day: 30)
        let calls = CallCounter()
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { day in
                calls.increment()
                if day == failedDay {
                    throw DayResolutionError.datasetAssumptionFailure(day)
                }
                return try resolvedDay(for: day, in: self.dataset)
            },
            nextMidnight: { nextNPTMidnight(after: $0) }
        )

        let built = failing.build(now: try supportedNow())

        // Three valid entries, then the error at day +3's intended activation;
        // no subsequent days are attempted.
        #expect(built.entries.count == 4)
        #expect(try built.entries[3].date == UTCWatchFixture.utc(2026, 9, 29, 18, 15))
        #expect(calls.value == 4)
        guard case .day(.calculationError(let components)) = built.entries[3].state else {
            Issue.record("Expected a calculation error entry")
            return
        }
        // The failed day's Gregorian identity was computed by progression, so
        // the context names it — and invents nothing beyond it.
        #expect(components.gregorianDay == "३०")
        #expect(components.gregorianMonthName == "September")
        #expect(components.gregorianYear == "२०२६")
        assertErrorPolicy(built, retryAt: built.entries[3].date.addingTimeInterval(15 * 60))
    }

    @Test func terminalEntryFailureRetainsTheHorizonAndStops() throws {
        // Day +14 (13 April 2028) fails after a fully supported horizon.
        let failedDay = GADay(year: 2028, month: 4, day: 13)
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { day in
                if day == failedDay {
                    throw DayResolutionError.datasetAssumptionFailure(day)
                }
                return try resolvedDay(for: day, in: self.dataset)
            },
            nextMidnight: { nextNPTMidnight(after: $0) }
        )
        let now = try UTCWatchFixture.utc(2028, 3, 30, 12, 0)

        let built = failing.build(now: now)

        #expect(built.entries.count == 15)
        guard case .day(.supported) = built.entries[13].state else {
            Issue.record("Expected the horizon to stay intact")
            return
        }
        guard case .day(.calculationError(let components)) = built.entries[14].state else {
            Issue.record("Expected a calculation error terminal entry")
            return
        }
        #expect(components.gregorianDay == "१३")
        assertErrorPolicy(built, retryAt: built.entries[14].date.addingTimeInterval(15 * 60))
    }

    @Test func unknownActivationDiscardsThePrefixForOneOriginalInstantError() throws {
        let now = try supportedNow()
        let calls = CallCounter()
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { day in
                calls.increment()
                return try resolvedDay(for: day, in: self.dataset)
            },
            nextMidnight: { _ in nil }
        )

        let built = failing.build(now: now)

        // The first future activation cannot be calculated: the prefix is
        // discarded and one error is returned at the original clock reading.
        #expect(built.entries.count == 1)
        #expect(built.entries[0].date == now)
        #expect(calls.value == 1)
        assertErrorPolicy(built, retryAt: now.addingTimeInterval(15 * 60))
    }

    // MARK: Helpers

    private func assertErrorPolicy(_ built: BuiltTimeline, retryAt expected: Date) {
        #expect(built.policy == .after(expected), "Expected an .after(\(expected)) reload policy, got \(built.policy)")
    }
}

/// A tiny call counter for seams whose invocation count is part of the
/// contract. Marked nonisolated because the seams call it from nonisolated
/// closures; each test owns its own counter, so there is no shared state.
nonisolated final class CallCounter: @unchecked Sendable {
    private var count = 0

    var value: Int { count }

    @discardableResult
    func increment() -> Int {
        count += 1
        return count
    }
}

/// UTC instant builder for the Watch target's tests, mirroring the core
/// suite's `UTCDateFixture`.
enum UTCWatchFixture {
    static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }
}
