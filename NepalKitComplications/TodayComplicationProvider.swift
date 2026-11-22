// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import NepalKitWatchSupport
import WidgetKit

/// The Today complication's timeline provider. The clock is injected and read
/// once per operation.
struct TodayComplicationProvider: TimelineProvider {
    /// The preview's sample day, resolved through core at render time.
    static let previewSampleDay = GregorianDate(year: 2026, month: 9, day: 27)

    private let now: @Sendable () -> Date
    private let dataset: CalendarDataset
    private let makeBuilder: @Sendable () -> TodayTimelineBuilder

    nonisolated init(now: @escaping @Sendable () -> Date = { Date.now }, dataset: CalendarDataset = .v2) {
        self.now = now
        self.dataset = dataset
        self.makeBuilder = {
            TodayTimelineBuilder(
                dataset: dataset,
                resolveDay: { try ResolvedDay($0, in: dataset) },
                nextMidnight: { TimeZone.nepal.nextMidnight(after: $0) }
            )
        }
    }

    /// For tests and fixtures that inject failures into the builder.
    nonisolated init(
        now: @escaping @Sendable () -> Date,
        dataset: CalendarDataset,
        makeBuilder: @escaping @Sendable () -> TodayTimelineBuilder
    ) {
        self.now = now
        self.dataset = dataset
        self.makeBuilder = makeBuilder
    }

    /// WidgetKit redacts placeholder content, so this does not read the clock.
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

    func placeholderEntry() -> TodayComplicationEntry {
        TodayComplicationEntry(date: .distantPast, state: .placeholder)
    }

    /// Previews use the fixed sample day; ordinary snapshots resolve Today.
    func snapshot(isPreview: Bool) -> TodayComplicationEntry {
        if isPreview {
            return previewEntry
        }
        let instant = now()
        return TodayComplicationEntry(date: instant, state: .day(watchDayDisplay(now: instant, settings: .watch, in: dataset)))
    }

    func timeline() -> BuiltTimeline {
        let instant = now()
        return makeBuilder().build(now: instant)
    }

    private var previewEntry: TodayComplicationEntry {
        let state: TodayComplicationState
        if let day = try? ResolvedDay(Self.previewSampleDay, in: dataset) {
            state = .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
        } else {
            state = .day(watchCalculationErrorDisplay(gregorianDay: Self.previewSampleDay, settings: .watch))
        }
        return TodayComplicationEntry(date: Self.previewSampleDay.noonUTC ?? .distantPast, state: state)
    }
}
