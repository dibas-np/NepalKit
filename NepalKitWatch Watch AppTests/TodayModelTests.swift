// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKitWatchApp

/// The Today lifecycle contract, tested through supplied state: launch and
/// activation resolve with one clock read, active midnight and clock-change
/// signals recompute from the current time, deactivation cancels scheduled
/// work and observation, reactivation resumes immediately across any number
/// of days, and repeated activation duplicates nothing. Sleep durations and
/// private task structure are not asserted.
@MainActor
struct TodayModelTests {
    // MARK: Fixtures

    /// A clock the test moves between operations. Only the MainActor touches
    /// it, so plain storage is safe despite the Sendable capture.
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

    /// A lock-guarded Bool the stream's termination handler can set from any
    /// thread while the MainActor test reads it.
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

    /// The injectable clock-change fixture: the stream the model consumes,
    /// the continuation the test yields signals into, and a flag set when the
    /// stream terminates — the deterministic marker that observation ended.
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
            // The stream body runs synchronously, so the continuation always
            // exists by here.
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
        nextMidnight: @escaping @Sendable (Date) -> Date? = { nextNPTMidnight(after: $0) }
    ) -> TodayModel {
        TodayModel(
            now: { clock.read() },
            dataset: dataset,
            clockChanges: { signals.stream },
            nextMidnight: nextMidnight
        )
    }

    /// Lets an in-flight event land: the stream handoff crosses one task
    /// boundary, so a few yields plus a short sleep is the deterministic
    /// settle.
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

        // One initial resolution and one from the single event; a duplicated
        // subscription would have read the clock twice for the event.
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

        // A forward clock change across a day boundary: the active session
        // must land on the new Nepal day.
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

        // Cancelling the observation task ends the stream; the termination
        // flag is the deterministic marker that teardown completed, after
        // which a yielded signal can no longer be consumed.
        try await waitUntil(timeout: .seconds(5)) { signals.terminated.isSet }
        signals.continuation.yield()
        await settle()

        #expect(clock.reads == readsAtDeactivation)
    }

    // MARK: The active-midnight refresh

    @Test func scheduledMidnightRefreshResolvesFromCurrentTime() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(
            clock: clock,
            signals: signals,
            // The next "midnight" is 50 ms away in test time; the wake must
            // resolve from the clock as it stands then.
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
            anchorBS: BSDay(year: 1975, month: 1, day: 1),
            anchorAD: GADay(year: 1918, month: 4, day: 13),
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
        // The instant was readable, so the NPT day was derived before the
        // table failed: the error carries it, and invents nothing beyond it.
        #expect(components.gregorianDay == "२७")
        model.deactivate()
    }

    // MARK: Helpers

    /// Polls until the condition holds or the timeout lapses — the bounded
    /// way to await a scheduled wake or teardown without asserting sleep
    /// durations.
    private func waitUntil(timeout: Duration, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Condition was not met within \(timeout)")
    }
}
