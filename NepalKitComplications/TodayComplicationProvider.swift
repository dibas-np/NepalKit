// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import WidgetKit

/// The Today complication's provider: a thin adapter that completes each
/// framework callback exactly once from the deterministic builder and snapshot
/// paths below. The clock is injected and read once per operation; nothing
/// here is MainActor-bound.
struct TodayComplicationProvider: TimelineProvider {
    /// The fixed preview sample day. Its displayed values are generated
    /// through core at render time, so nothing here hand-maintains a paired
    /// date: a dataset change moves the preview with it.
    static let previewSampleDay = GADay(year: 2026, month: 9, day: 27)

    private let now: @Sendable () -> Date
    private let dataset: CalendarDataset

    init(now: @escaping @Sendable () -> Date = { Date.now }, dataset: CalendarDataset = .v2) {
        self.now = now
        self.dataset = dataset
    }

    /// Neutral and clock-free: WidgetKit redacts placeholder content, so the
    /// placeholder neither reads the clock nor resolves Today.
    func placeholder(in context: Context) -> TodayComplicationEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayComplicationEntry) -> Void) {
        completion(snapshot(isPreview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayComplicationEntry>) -> Void) {
        let built = timeline()
        completion(Timeline(entries: built.entries, policy: built.policy))
    }

    /// The placeholder entry, extracted like the snapshot path so tests
    /// exercise the same content the adapter returns.
    func placeholderEntry() -> TodayComplicationEntry {
        TodayComplicationEntry(date: .distantPast, state: .placeholder)
    }

    /// The snapshot entry, parameterized by `isPreview` so tests exercise the
    /// same path the adapter unwraps from the context. Ordinary snapshots
    /// resolve actual Today with one clock read; preview snapshots use the
    /// fixed core-generated sample; snapshot failures stay errors.
    func snapshot(isPreview: Bool) -> TodayComplicationEntry {
        if isPreview {
            return previewEntry
        }
        let instant = now()
        let state: TodayComplicationState
        do {
            let day = try resolvedDay(now: instant, in: dataset)
            state = .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
        } catch {
            // A snapshot failure is an error, never a boundary state or a
            // fabricated sample; the NPT day was not derived, so there is no
            // Gregorian context to carry.
            state = .day(watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch))
        }
        return TodayComplicationEntry(date: instant, state: state)
    }

    /// The full timeline from one clock read through the deterministic
    /// builder, with production's resolver and midnight seam.
    func timeline() -> BuiltTimeline {
        let instant = now()
        let dataset = self.dataset
        let builder = TodayTimelineBuilder(
            dataset: dataset,
            resolveDay: { try resolvedDay(for: $0, in: dataset) },
            nextMidnight: { nextNPTMidnight(after: $0) }
        )
        return builder.build(now: instant)
    }

    private var previewEntry: TodayComplicationEntry {
        let state: TodayComplicationState
        if let day = try? resolvedDay(for: Self.previewSampleDay, in: dataset) {
            state = .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
        } else {
            state = .day(watchCalculationErrorDisplay(gregorianDay: Self.previewSampleDay, settings: .watch))
        }
        return TodayComplicationEntry(date: noonUTC(for: Self.previewSampleDay) ?? .distantPast, state: state)
    }
}
