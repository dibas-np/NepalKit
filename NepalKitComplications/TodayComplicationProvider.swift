// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import NepalKitWatchSupport
import WidgetKit

struct TodayComplicationProvider: TimelineProvider {
    static let previewSampleDay = GregorianDate(year: 2026, month: 9, day: 27)

    private let now: @Sendable () -> Date
    private let dataset: CalendarDataset
    private let makeBuilder: @Sendable () -> TodayTimelineBuilder

    nonisolated init(now: @escaping @Sendable () -> Date = { Date.now }, dataset: CalendarDataset = .bundled) {
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

    nonisolated init(
        now: @escaping @Sendable () -> Date,
        dataset: CalendarDataset,
        makeBuilder: @escaping @Sendable () -> TodayTimelineBuilder
    ) {
        self.now = now
        self.dataset = dataset
        self.makeBuilder = makeBuilder
    }

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
        let state = TodayComplicationState.day(watchDayDisplay(for: Self.previewSampleDay, settings: .watch, in: dataset))
        return TodayComplicationEntry(date: Self.previewSampleDay.noonUTC ?? .distantPast, state: state)
    }
}
