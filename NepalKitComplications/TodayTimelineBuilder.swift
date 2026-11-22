// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import NepalKitWatchSupport
import WidgetKit

struct BuiltTimeline {
    let entries: [TodayComplicationEntry]
    let policy: TimelineReloadPolicy
}

struct TodayTimelineBuilder: Sendable {
    static let horizonLastOffset = 13

    static let errorRetryInterval: TimeInterval = 15 * 60

    let dataset: CalendarDataset
    var resolveDay: @Sendable (GregorianDate) throws -> ResolvedDay
    var nextMidnight: @Sendable (Date) -> Date?

    func build(now: Date) -> BuiltTimeline {
        guard let today = GregorianDate.today(now: now) else {
            return singleErrorTimeline(at: now, gregorianDay: nil)
        }
        var nextActivation = now
        switch horizonEntries(from: today, now: now, &nextActivation) {
        case .stopped(let timeline):
            return timeline
        case .completed(let entries):
            return terminalEntries(from: today, now: now, prefix: entries, &nextActivation)
                ?? BuiltTimeline(entries: entries, policy: .atEnd)
        }
    }

    private enum HorizonOutcome {
        case stopped(BuiltTimeline)
        case completed([TodayComplicationEntry])
    }

    private func horizonEntries(
        from today: GregorianDate,
        now: Date,
        _ nextActivation: inout Date
    ) -> HorizonOutcome {
        var entries: [TodayComplicationEntry] = []
        for offset in 0 ... Self.horizonLastOffset {
            guard let activation = activation(forOffset: offset, now: now, &nextActivation) else {
                return .stopped(singleErrorTimeline(at: now, gregorianDay: nil))
            }
            guard let gregorian = today.advanced(byDays: offset) else {
                return .stopped(prefixRetainingError(at: activation, gregorianDay: nil, prefix: entries))
            }
            do {
                let day = try resolveDay(gregorian)
                entries.append(TodayComplicationEntry(
                    date: activation,
                    state: .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
                ))
            } catch {
                return .stopped(prefixRetainingError(at: activation, gregorianDay: gregorian, prefix: entries))
            }
        }
        return .completed(entries)
    }

    private func activation(forOffset offset: Int, now: Date, _ nextActivation: inout Date) -> Date? {
        if offset == 0 {
            return now
        }
        guard let midnight = nextMidnight(nextActivation) else { return nil }
        nextActivation = midnight
        return midnight
    }

    /// Appends the boundary entry when day +13 is the dataset's last day.
    /// Returns nil when the horizon needs no terminal entry.
    private func terminalEntries(
        from today: GregorianDate,
        now: Date,
        prefix: [TodayComplicationEntry],
        _ nextActivation: inout Date
    ) -> BuiltTimeline? {
        guard let maximum = dataset.gregorianEnd,
              let lastHorizonDay = today.advanced(byDays: Self.horizonLastOffset),
              lastHorizonDay == maximum
        else { return nil }
        guard let terminalMidnight = nextMidnight(nextActivation) else {
            return singleErrorTimeline(at: now, gregorianDay: nil)
        }
        guard let terminalDay = today.advanced(byDays: Self.horizonLastOffset + 1) else {
            return prefixRetainingError(at: terminalMidnight, gregorianDay: nil, prefix: prefix)
        }
        do {
            let day = try resolveDay(terminalDay)
            var entries = prefix
            entries.append(TodayComplicationEntry(
                date: terminalMidnight,
                state: .day(watchDayDisplay(for: day, settings: .watch, in: dataset))
            ))
            return BuiltTimeline(entries: entries, policy: .atEnd)
        } catch {
            return prefixRetainingError(at: terminalMidnight, gregorianDay: terminalDay, prefix: prefix)
        }
    }

    private func prefixRetainingError(
        at activation: Date,
        gregorianDay: GregorianDate?,
        prefix: [TodayComplicationEntry]
    ) -> BuiltTimeline {
        var entries = prefix
        entries.append(errorEntry(at: activation, gregorianDay: gregorianDay))
        return BuiltTimeline(
            entries: entries,
            policy: .after(activation.addingTimeInterval(Self.errorRetryInterval))
        )
    }

    private func errorEntry(at activation: Date, gregorianDay: GregorianDate?) -> TodayComplicationEntry {
        TodayComplicationEntry(
            date: activation,
            state: .day(watchCalculationErrorDisplay(gregorianDay: gregorianDay, settings: .watch))
        )
    }

    private func singleErrorTimeline(at instant: Date, gregorianDay: GregorianDate?) -> BuiltTimeline {
        BuiltTimeline(
            entries: [errorEntry(at: instant, gregorianDay: gregorianDay)],
            policy: .after(instant.addingTimeInterval(Self.errorRetryInterval))
        )
    }
}
