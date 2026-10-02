// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import WidgetKit

/// The provider adapter contract: one clock read per operation, callbacks
/// derived entirely from the deterministic paths, clock-free previews and
/// placeholders, and snapshot failures that stay errors.
struct TodayComplicationProviderTests {
    private let dataset = CalendarDataset.v2

    @Test func timelineReadsTheClockExactlyOnce() {
        let clock = CallCounter()
        let provider = TodayComplicationProvider(now: { clock.increment(); return .distantPast })

        _ = provider.timeline()

        #expect(clock.value == 1)
    }

    @Test func actualSnapshotReadsTheClockExactlyOnce() {
        let clock = CallCounter()
        let provider = TodayComplicationProvider(now: { clock.increment(); return .distantPast })

        _ = provider.snapshot(isPreview: false)

        #expect(clock.value == 1)
    }

    @Test func placeholderReadsNoClockAndCarriesNoDay() {
        let clock = CallCounter()
        let provider = TodayComplicationProvider(now: { clock.increment(); return .distantPast })

        let entry = provider.placeholderEntry()

        #expect(clock.value == 0)
        #expect(entry.state == .placeholder)
    }

    @Test func previewSnapshotIsFixedAndCoreGenerated() throws {
        let clock = CallCounter()
        let provider = TodayComplicationProvider(now: { clock.increment(); return .distantPast })

        let entry = provider.snapshot(isPreview: true)

        // The preview never touches the clock: it renders the fixed sample
        // day through core.
        #expect(clock.value == 0)
        guard case .day(.supported(let components)) = entry.state else {
            Issue.record("Expected the preview sample to resolve as a supported day")
            return
        }
        // 27 September 2026 resolves through the shared dataset to 11 Ashoj 2083.
        #expect(components.bikramSambatDay == "११")
        #expect(components.bikramSambatMonthName == "असोज")
        #expect(components.bikramSambatYear == "२०८३")
    }

    @Test func actualSnapshotResolvesTodayThroughCore() throws {
        // 26 Sep 2026, 18:30 UTC = 11 Ashoj 2083 in Nepal Time.
        let now = try UTCWatchFixture.utc(2026, 9, 26, 18, 30)
        let provider = TodayComplicationProvider(now: { now })

        let entry = provider.snapshot(isPreview: false)

        #expect(entry.date == now)
        guard case .day(.supported(let components)) = entry.state else {
            Issue.record("Expected a supported snapshot")
            return
        }
        #expect(components.bikramSambatDay == "११")
        #expect(components.bikramSambatYear == "२०८३")
    }

    @Test func snapshotFailureStaysAnErrorAndCarriesTheDerivedDay() throws {
        // A table whose supported-range year has zero-length months cannot
        // resolve anything: the snapshot must report the calculation error,
        // not a boundary or a fabricated sample. The NPT day itself was
        // derived, so the error carries it as context.
        let broken = CalendarDataset(
            version: "broken-snapshot-test",
            years: [1975: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]],
            anchorBS: BSDay(year: 1975, month: 1, day: 1),
            anchorAD: GADay(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1975
        )
        // 26 Sep 2026, 18:30 UTC: the NPT day 2026-09-27 is derived before
        // the table fails to answer it.
        let now = try UTCWatchFixture.utc(2026, 9, 26, 18, 30)
        let provider = TodayComplicationProvider(now: { now }, dataset: broken)

        let entry = provider.snapshot(isPreview: false)

        guard case .day(.calculationError(let components)) = entry.state else {
            Issue.record("Expected a calculation error snapshot")
            return
        }
        #expect(components.gregorianDay == "२७")
    }

    @Test func timelineFailureFallsBackToOneOriginalInstantError() throws {
        let broken = CalendarDataset(
            version: "broken-timeline-test",
            years: [1975: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]],
            anchorBS: BSDay(year: 1975, month: 1, day: 1),
            anchorAD: GADay(year: 1918, month: 4, day: 13),
            supportedRange: 1975 ... 1975
        )
        let now = try UTCWatchFixture.utc(2026, 9, 26, 18, 30)
        let provider = TodayComplicationProvider(now: { now }, dataset: broken)

        let built = provider.timeline()

        #expect(built.entries.count == 1)
        #expect(built.entries[0].date == now)
        #expect(built.policy == .after(now.addingTimeInterval(15 * 60)))
    }
}
