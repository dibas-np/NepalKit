// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import Synchronization
import NepalKitCore
import WidgetKit

struct TodayTimelineBuilderTests {
    private let dataset = CalendarDataset.v2

    private func supportedNow() throws -> Date {
        try UTCWatchFixture.utc(2026, 9, 26, 18, 30)
    }

    private var builder: TodayTimelineBuilder {
        TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { try ResolvedDay($0, in: self.dataset) },
            nextMidnight: { TimeZone.nepal.nextMidnight(after: $0) }
        )
    }

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

        #expect(try built.entries[1].date == UTCWatchFixture.utc(2026, 9, 27, 18, 15))
        #expect(try built.entries[2].date == UTCWatchFixture.utc(2026, 9, 28, 18, 15))
        #expect(try built.entries[13].date == UTCWatchFixture.utc(2026, 10, 9, 18, 15))
    }

    @Test func onlyFutureEntriesAreTwentyFourHoursApart() throws {
        let built = builder.build(now: try supportedNow())

        #expect(built.entries[1].date.timeIntervalSince(built.entries[0].date) != 86_400)
        for index in 1 ..< built.entries.count - 1 {
            let spacing = built.entries[index + 1].date.timeIntervalSince(built.entries[index].date)
            #expect(spacing == 86_400)
        }
    }

    @Test func everyEntryCarriesItsResolvedDayInOrder() throws {
        let built = builder.build(now: try supportedNow())

        guard case .day(.supported(let first)) = built.entries[0].state else {
            Issue.record("Expected a supported entry zero")
            return
        }
        #expect(first.bikramSambatDay == "११")
        guard case .day(.supported(let last)) = built.entries[13].state else {
            Issue.record("Expected a supported final entry")
            return
        }
        #expect(last.gregorianDay == "१०")
        #expect(last.gregorianMonthName == "October")
        #expect(last.bikramSambatDay == "२४")
    }

    @Test func beforeMinimumTodayEntersSupport() throws {
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
        #expect(last.gregorianDay == "२६")
        #expect(last.gregorianMonthName == "April")
    }

    @Test func maximumEarlierInTheHorizonDoesNotDuplicateTheBoundary() throws {
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

    @Test func firstDayFailureAppendsOneErrorAtTheOriginalReadingAndStops() throws {
        let now = try supportedNow()
        let calls = CallCounter()
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { _ in calls.increment(); throw DayResolutionError.datasetAssumptionFailure(GregorianDate(year: 2026, month: 9, day: 27)) },
            nextMidnight: { TimeZone.nepal.nextMidnight(after: $0) }
        )

        let built = failing.build(now: now)

        #expect(built.entries.count == 1)
        #expect(built.entries[0].date == now)
        guard case .day(.calculationError(let components)) = built.entries[0].state else {
            Issue.record("Expected a calculation error entry")
            return
        }
        #expect(components.gregorianDay == "२७")
        #expect(components.gregorianMonthName == "September")
        #expect(calls.value == 1)
        assertErrorPolicy(built, retryAt: now.addingTimeInterval(15 * 60))
    }

    @Test func intermediateFailureRetainsThePrefixAndStops() throws {
        let failedDay = GregorianDate(year: 2026, month: 9, day: 30)
        let calls = CallCounter()
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { day in
                calls.increment()
                if day == failedDay {
                    throw DayResolutionError.datasetAssumptionFailure(day)
                }
                return try ResolvedDay(day, in: self.dataset)
            },
            nextMidnight: { TimeZone.nepal.nextMidnight(after: $0) }
        )

        let built = failing.build(now: try supportedNow())

        #expect(built.entries.count == 4)
        #expect(try built.entries[3].date == UTCWatchFixture.utc(2026, 9, 29, 18, 15))
        #expect(calls.value == 4)
        guard case .day(.calculationError(let components)) = built.entries[3].state else {
            Issue.record("Expected a calculation error entry")
            return
        }
        #expect(components.gregorianDay == "३०")
        #expect(components.gregorianMonthName == "September")
        #expect(components.gregorianYear == "२०२६")
        assertErrorPolicy(built, retryAt: built.entries[3].date.addingTimeInterval(15 * 60))
    }

    @Test func terminalEntryFailureRetainsTheHorizonAndStops() throws {
        let failedDay = GregorianDate(year: 2028, month: 4, day: 13)
        let failing = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { day in
                if day == failedDay {
                    throw DayResolutionError.datasetAssumptionFailure(day)
                }
                return try ResolvedDay(day, in: self.dataset)
            },
            nextMidnight: { TimeZone.nepal.nextMidnight(after: $0) }
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
                return try ResolvedDay(day, in: self.dataset)
            },
            nextMidnight: { _ in nil }
        )

        let built = failing.build(now: now)

        #expect(built.entries.count == 1)
        #expect(built.entries[0].date == now)
        #expect(calls.value == 1)
        assertErrorPolicy(built, retryAt: now.addingTimeInterval(15 * 60))
    }

    private func assertErrorPolicy(_ built: BuiltTimeline, retryAt expected: Date) {
        #expect(built.policy == .after(expected), "Expected an .after(\(expected)) reload policy, got \(built.policy)")
    }
}

nonisolated final class CallCounter: Sendable {
    private let count = Mutex(0)

    var value: Int { count.withLock { $0 } }

    @discardableResult
    func increment() -> Int {
        count.withLock {
            $0 += 1
            return $0
        }
    }
}

enum UTCWatchFixture {
    static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }
}
