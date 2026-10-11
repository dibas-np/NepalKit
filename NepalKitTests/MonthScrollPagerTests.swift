// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
import NepalKitCore
@testable import NepalKit

/// Paging the month grid by scrolling and by the arrow keys.
@MainActor
struct MonthScrollPagerTests {
    @Test func aTrackpadGesturePagesOnceAfterTheThreshold() {
        var pager = MonthScrollPager()
        // Scrolling down: small negative deltas, as a swipe reports them.
        #expect(pager.step(deltaY: -5, phase: .began) == 0)
        #expect(pager.step(deltaY: -10, phase: .changed) == 0)
        #expect(pager.step(deltaY: -10, phase: .changed) == 1)
        // The rest of the same gesture, and its momentum, page no further.
        #expect(pager.step(deltaY: -40, phase: .changed) == 0)
        #expect(pager.step(deltaY: 0, phase: .ended) == 0)
        #expect(pager.step(deltaY: -60, phase: .momentum) == 0)
        // A new gesture pages again, upward this time.
        #expect(pager.step(deltaY: 30, phase: .began) == -1)
    }

    @Test func aShortOrWaveringGestureDoesNotPage() {
        var pager = MonthScrollPager()
        #expect(pager.step(deltaY: -10, phase: .began) == 0)
        #expect(pager.step(deltaY: 8, phase: .changed) == 0)
        #expect(pager.step(deltaY: -10, phase: .changed) == 0)
        #expect(pager.step(deltaY: 0, phase: .ended) == 0)
        // Travel does not carry over into the next gesture.
        #expect(pager.step(deltaY: -MonthScrollPager.threshold + 1, phase: .began) == 0)
    }

    @Test func eachWheelNotchPagesOnce() {
        var pager = MonthScrollPager()
        #expect(pager.step(deltaY: -1, phase: .discrete) == 1)
        #expect(pager.step(deltaY: -1, phase: .discrete) == 1)
        #expect(pager.step(deltaY: 1, phase: .discrete) == -1)
        #expect(pager.step(deltaY: 0, phase: .discrete) == 0)
    }

    @Test func eventPhasesMapToTheirPlaceInTheGesture() {
        typealias Phase = MonthScrollPager.Phase
        #expect(Phase(phase: [], momentumPhase: []) == .discrete)
        #expect(Phase(phase: .began, momentumPhase: []) == .began)
        #expect(Phase(phase: .changed, momentumPhase: []) == .changed)
        #expect(Phase(phase: .ended, momentumPhase: []) == .ended)
        #expect(Phase(phase: .cancelled, momentumPhase: []) == .ended)
        #expect(Phase(phase: .mayBegin, momentumPhase: []) == .ended)
        #expect(Phase(phase: [], momentumPhase: .changed) == .momentum)
        #expect(Phase(phase: [], momentumPhase: .began) == .momentum)
    }

    @Test func scrollingThroughTheModelMovesTheShownMonth() throws {
        let model = MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
        model.scroll(deltaY: -30, phase: .began)
        #expect(model.shown == MonthGridMonth(year: 2082, month: 2))
        model.scroll(deltaY: -30, phase: .changed)
        #expect(model.shown == MonthGridMonth(year: 2082, month: 2))
        model.scroll(deltaY: 0, phase: .ended)
        model.scroll(deltaY: 1, phase: .discrete)
        model.scroll(deltaY: 1, phase: .discrete)
        #expect(model.shown == MonthGridMonth(year: 2081, month: 12))
    }

    @Test func pagingStopsAtTheSupportedRangesEnds() throws {
        let model = MonthGridModel(now: try TestDates.utc(2028, 4, 12, 6, 0))
        model.page(by: 1)
        #expect(model.shown == MonthGridMonth(year: 2084, month: 12))
        model.page(by: -1)
        #expect(model.shown == MonthGridMonth(year: 2084, month: 11))
        model.page(by: 0)
        #expect(model.shown == MonthGridMonth(year: 2084, month: 11))

        let first = MonthGridModel(now: try TestDates.utc(1918, 4, 13, 6, 0))
        first.scroll(deltaY: 1, phase: .discrete)
        #expect(first.shown == MonthGridMonth(year: 1975, month: 1))
    }
}
