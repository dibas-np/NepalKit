// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import SwiftUI
import Synchronization
@testable import NepalKitWatchApp

@MainActor
struct TodayModelTests {
    nonisolated final class MutableClock: Sendable {
        private let state: Mutex<(value: Date, reads: Int)>

        init(_ value: Date) {
            state = Mutex((value, 0))
        }

        var value: Date {
            get { state.withLock { $0.value } }
            set { state.withLock { $0.value = newValue } }
        }

        var reads: Int { state.withLock { $0.reads } }

        func read() -> Date {
            state.withLock {
                $0.reads += 1
                return $0.value
            }
        }
    }

    nonisolated final class FlagBox: Sendable {
        private let value = Mutex(false)

        func set() {
            value.withLock { $0 = true }
        }

        var isSet: Bool { value.withLock { $0 } }
    }

    nonisolated final class SignalFixture: Sendable {
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

    /// Ends the stream and waits for the model to process everything sent before.
    private func drain(_ signals: SignalFixture, _ model: TodayModel) async {
        signals.continuation.finish()
        await model.clockChangeTask?.value
    }

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

        signals.continuation.yield()
        await drain(signals, model)

        #expect(clock.reads == 2)
        model.deactivate()
    }

    @Test func clockChangeSignalRecomputesFromCurrentTime() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()

        clock.value = try UTCWatchFixture.utc(2026, 9, 27, 18, 30)
        signals.continuation.yield()
        await drain(signals, model)

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
        let observation = model.clockChangeTask
        model.deactivate()
        let readsAtDeactivation = clock.reads

        await observation?.value
        #expect(signals.terminated.isSet)
        signals.continuation.yield()

        #expect(clock.reads == readsAtDeactivation)
    }

    @Test func deactivationDiscardsBufferedClockChanges() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()
        let displayAtDeactivation = model.display

        clock.value = try UTCWatchFixture.utc(2026, 9, 27, 18, 30)
        signals.continuation.yield()
        let observation = model.clockChangeTask
        model.deactivate()
        await observation?.value

        #expect(clock.reads == 1)
        #expect(model.display == displayAtDeactivation)
    }

    @Test func scheduledMidnightRefreshResolvesFromCurrentTime() async throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(
            clock: clock,
            signals: signals,
            nextMidnight: { $0.addingTimeInterval(0.05) }
        )
        model.activate()
        let midnight = model.midnightTask
        #expect(clock.reads == 1)

        clock.value = try UTCWatchFixture.utc(2026, 9, 27, 18, 30)
        await midnight?.value
        #expect(clock.reads == 2)

        guard case .supported(let components) = model.display else {
            Issue.record("Expected a supported display after the wake")
            return
        }
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
        let midnight = model.midnightTask
        model.deactivate()

        await midnight?.value

        #expect(clock.reads == 1)
    }

    @Test func onlyTheBackgroundPhaseDeactivates() {
        #expect(shouldStayActive(in: .active))
        #expect(shouldStayActive(in: .inactive))
        #expect(!shouldStayActive(in: .background))
    }

    @Test func multiDayResumeRecomputesImmediately() throws {
        let clock = MutableClock(try anchoredInstant())
        let signals = SignalFixture()
        let model = makeModel(clock: clock, signals: signals)
        model.activate()
        model.deactivate()

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
        #expect(components.gregorianDay == "२७")
        model.deactivate()
    }
}

extension TodayModelTests {
    @Test func displayAtAnInstantPastNepalMidnightIsTheNewDay() throws {
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
