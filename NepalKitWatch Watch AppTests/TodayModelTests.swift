// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import SwiftUI
@testable import NepalKitWatchApp

@MainActor
struct TodayModelTests {
    // MARK: Fixtures

    /// Only the MainActor touches it, so plain storage is safe.
    nonisolated final class MutableClock: @unchecked Sendable {
        var value: Date
        var reads = 0

        init(_ value: Date) {
            self.value = value
        }

        func read() -> Date {
            reads += 1
            return value
        }
    }

    nonisolated final class FlagBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        func set() {
            lock.lock()
            value = true
            lock.unlock()
        }

        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    /// A clock-change stream the test drives, with a flag set on termination.
    nonisolated final class SignalFixture: @unchecked Sendable {
        let stream: ClockChangeStream
        let continuation: AsyncStream<Void>.Continuation
        let terminated = FlagBox()

        init() {
            var captured: AsyncStream<Void>.Continuation?
            let flag = terminated
            self.stream = AsyncStream { continuation in
                captured = continuation
                continuation.onTermination = { _ in
                    flag.set()
                }
            }
            guard let captured else {
                preconditionFailure("AsyncStream must run its body synchronously")
            }
            self.continuation = captured
        }
    }

    private func anchoredInstant() throws -> Date {
        try UTCWatchFixture.utc(2026, 9, 26, 18, 30)
    }

    private func makeModel(
        clock: MutableClock,
        signals: SignalFixture,
        dataset: CalendarDataset = .v2,
        nextMidnight: @escaping @Sendable (Date) -> Date? = { TimeZone.nepal.nextMidnight(after: $0) }
    ) -> TodayModel {
        TodayModel(
            now: { clock.read() },
            dataset: dataset,
            clockChanges: { signals.stream },
            nextMidnight: nextMidnight
        )
    }

    /// Lets an in-flight stream event reach the model.
    private func settle() async {
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(50))
    }

    // MARK: Launch and activation

    @Test func activationResolvesTodayWithOneClockRead() throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)

        model.activate()

        #expect(clock.reads == 1)
        guard case .supported(let components) = model.display else {
            Issue.record("Expected a supported display")
            return
        }
        #expect(components.bikramSambatDay == "११")
        #expect(components.bikramSambatMonthName == "असोज")
        #expect(components.bikramSambatYear == "२०८३")
        model.deactivate()
    }

    @Test func repeatedActivationDoesNotDuplicateWork() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)

        model.activate()
        model.activate()

        // A duplicated subscription would read the clock twice for the event.
        signals.continuation.yield()
        await settle()

        #expect(clock.reads == 2)
        model.deactivate()
    }

    // MARK: Active clock-change handling

    @Test func clockChangeSignalRecomputesFromCurrentTime() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()

        clock.value = try UTCWatchFixture.utc(2026, 9, 27, 18, 30)
        signals.continuation.yield()
        await settle()

        #expect(clock.reads == 2)
        guard case .supported(let components) = model.display else {
            Issue.record("Expected a supported display after the change")
            return
        }
        #expect(components.bikramSambatDay == "१२")
        model.deactivate()
    }

    @Test func deactivationCancelsClockChangeObservation() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()
        model.deactivate()
        let readsAtDeactivation = clock.reads

        try await waitUntil(timeout: .seconds(5)) { signals.terminated.isSet }
        signals.continuation.yield()
        await settle()

        #expect(clock.reads == readsAtDeactivation)
    }

    @Test func deactivationDiscardsBufferedClockChanges() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()
        let displayAtDeactivation = model.display

        // No suspension lets the observer run before the task is cancelled.
        clock.value = try UTCWatchFixture.utc(2026, 9, 27, 18, 30)
        signals.continuation.yield()
        model.deactivate()
        await settle()

        #expect(clock.reads == 1)
        #expect(model.display == displayAtDeactivation)
    }

    // MARK: The active-midnight refresh

    @Test func scheduledMidnightRefreshResolvesFromCurrentTime() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(
            clock: clock,
            signals: signals,
            nextMidnight: { $0.addingTimeInterval(0.05) }
        )
        model.activate()
        #expect(clock.reads == 1)

        clock.value = try UTCWatchFixture.utc(2026, 9, 27, 18, 30)
        try await waitUntil(timeout: .seconds(5)) { clock.reads >= 2 }

        guard case .supported(let components) = model.display else {
            Issue.record("Expected a supported display after the wake")
            return
        }
        // Resolved from the current reading, not the instant scheduled from.
        #expect(components.bikramSambatDay == "१२")
        model.deactivate()
    }

    @Test func deactivationCancelsScheduledMidnightWork() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(
            clock: clock,
            signals: signals,
            nextMidnight: { $0.addingTimeInterval(0.05) }
        )
        model.activate()
        model.deactivate()

        try await Task.sleep(for: .milliseconds(300))

        #expect(clock.reads == 1)
    }

    // MARK: Scene phase

    @Test func onlyTheBackgroundPhaseDeactivates() {
        #expect(shouldStayActive(in: .active))
        #expect(shouldStayActive(in: .inactive))
        #expect(!shouldStayActive(in: .background))
    }

    @Test func inactivePhaseKeepsTheMidnightRefresh() async throws {
        // Always On: a dimmed screen is still visible.
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(
            clock: clock,
            signals: signals,
            nextMidnight: { $0.addingTimeInterval(0.05) }
        )
        model.activate()
        if !shouldStayActive(in: .inactive) {
            model.deactivate()
        }

        try await waitUntil(timeout: .seconds(5)) { clock.reads >= 2 }

        model.deactivate()
    }

    // MARK: Inactive resume

    @Test func multiDayResumeRecomputesImmediately() throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()
        model.deactivate()

        // Two inactive days later, reactivation recomputes at once.
        clock.value = try UTCWatchFixture.utc(2026, 9, 28, 18, 30)
        model.activate()

        #expect(clock.reads == 2)
        guard case .supported(let components) = model.display else {
            Issue.record("Expected a supported display after resume")
            return
        }
        #expect(components.bikramSambatDay == "१३")
        model.deactivate()
    }

    // MARK: States

    @Test func pastTheMaximumTodayRendersTheAfterBoundary() throws {
        let clock = MutableClock(try UTCWatchFixture.utc(2028, 4, 13, 12, 0))
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)

        model.activate()

        guard case .rangeBoundary(let boundary) = model.display else {
            Issue.record("Expected the after-maximum boundary")
            return
        }
        #expect(boundary.side == .after)
        #expect(boundary.contextLine == "Supported through २०८४ BS")
        model.deactivate()
    }

    @Test func brokenDatasetRendersACalculationErrorWithTheDerivedDay() throws {
        let broken = CalendarDataset(
            version: "broken-today-test",
            years: [1975: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]],
            anchorBikramSambat: BikramSambatDate(year: 1975, month: 1, day: 1),
            anchorGregorian: GregorianDate(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1975
        )
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals, dataset: broken)

        model.activate()

        guard case .calculationError(let components) = model.display else {
            Issue.record("Expected a calculation error display")
            return
        }
        // The NPT day was derived before the table failed.
        #expect(components.gregorianDay == "२७")
        model.deactivate()
    }

    // MARK: Helpers

    private func waitUntil(timeout: Duration, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Condition was not met within \(timeout)")
    }
}

// MARK: Always On

extension TodayModelTests {
    @Test func displayAtAnInstantPastNepalMidnightIsTheNewDay() throws {
        // `display(at:)` alone must cross midnight (18:15 UTC).
        let clock = MutableClock(try anchoredInstant())
        let model = makeModel(clock: clock, signals: SignalFixture())

        let before = model.display(at: try UTCWatchFixture.utc(2026, 9, 26, 18, 14))
        let after = model.display(at: try UTCWatchFixture.utc(2026, 9, 26, 18, 16))

        guard case .supported(let old) = before, case .supported(let new) = after else {
            Issue.record("Expected supported displays")
            return
        }
        #expect(old.bikramSambatDay == "१०")
        #expect(new.bikramSambatDay == "११")
        #expect(new.bikramSambatMonthName == "असोज")
        #expect(clock.reads == 0)
        #expect(model.display == nil)
    }
}
