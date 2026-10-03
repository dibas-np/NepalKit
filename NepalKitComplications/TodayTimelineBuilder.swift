// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import WidgetKit

/// The timeline a complication request receives: ordered entries and the
/// reload policy selected for them.
struct BuiltTimeline {
    let entries: [TodayComplicationEntry]
    let policy: TimelineReloadPolicy
}

/// Builds the fourteen-Gregorian-day Today timeline, plus its one conditional
/// terminal boundary entry, from a single clock reading.
///
/// Pure and deterministic. The clock is read once by the caller; the day
/// resolver and the midnight seam are injected so tests can pin failures at
/// exact offsets without touching the system clock. Production wires the core
/// resolver and `nextNPTMidnight(after:)` — nothing here maintains a second
/// calendar oracle or re-reads the clock.
///
/// The contract, from the accepted handoff: entry zero activates at the
/// original reading, future entries at successive Nepal midnights (only
/// future-midnight intervals are twenty-four hours apart — the first interval
/// varies). Every day resolves independently, boundaries included, so a
/// before-minimum Today enters support and an after-maximum Today still fills
/// the horizon. When day +13 is the dataset's maximum supported Gregorian day,
/// exactly one range boundary entry is appended at day +14's midnight; when
/// the maximum falls earlier in the horizon its following boundary day is
/// already part of it and nothing is duplicated. At the first calculation
/// failure the valid prefix is kept and a distinct error entry is appended at
/// that day's intended activation, then construction stops; if an activation
/// cannot be calculated at all, the prefix is discarded in favor of one error
/// entry at the original reading. Successful timelines — boundary entries
/// included — use `.atEnd`; any timeline carrying a calculation error asks for
/// `.after(errorActivation + 15 minutes)`. No exact reload or recovery time is
/// promised beyond that request.
struct TodayTimelineBuilder: Sendable {
    /// The last offset of the ordinary horizon: Today through day +13.
    static let horizonLastOffset = 13

    /// How long after an error entry WidgetKit is asked to try again. A
    /// requested earliest reload, never a guarantee.
    static let errorRetryInterval: TimeInterval = 15 * 60

    let dataset: CalendarDataset
    var resolveDay: @Sendable (GADay) throws -> ResolvedDay
    var nextMidnight: @Sendable (Date) -> Date?

    /// Builds the timeline for the supplied instant — the one clock reading
    /// this whole construction is anchored to.
    func build(now: Date) -> BuiltTimeline {
        guard let today = todayAD(now: now) else {
            // The instant itself is unreadable: no prefix exists and no
            // Gregorian context may be invented.
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

    /// How the ordinary horizon resolved.
    private enum HorizonOutcome {
        /// Construction stopped early: return this timeline unchanged.
        case stopped(BuiltTimeline)
        /// Every day through the horizon end resolved.
        case completed([TodayComplicationEntry])
    }

    /// Resolves Today through day +13, one independently resolved day per
    /// entry.
    private func horizonEntries(
        from today: GADay,
        now: Date,
        _ nextActivation: inout Date
    ) -> HorizonOutcome {
        var entries: [TodayComplicationEntry] = []
        for offset in 0 ... Self.horizonLastOffset {
            guard let activation = activation(forOffset: offset, now: now, &nextActivation) else {
                // This day's intended activation cannot be calculated, so the
                // prefix is discarded for one error at the original reading —
                // never a fabricated timestamp.
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

    /// The entry's activation: entry zero at the original reading, future
    /// days at the next Nepal midnight of the chain.
    private func activation(forOffset offset: Int, now: Date, _ nextActivation: inout Date) -> Date? {
        if offset == 0 {
            return now
        }
        guard let midnight = nextMidnight(nextActivation) else { return nil }
        nextActivation = midnight
        return midnight
    }

    /// The conditional terminal entry: only when day +13 is exactly the
    /// dataset's maximum supported Gregorian day. Earlier maxima already
    /// carry their following boundary inside the horizon; maxima beyond it or
    /// behind Today need no extra entry. Returns the timeline to return as-is
    /// when the terminal entry fails, or nil when the horizon stands.
    private func terminalEntries(
        from today: GADay,
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

    /// The failed day keeps the valid prefix: a distinct error entry at the
    /// day's intended activation, then construction stops and WidgetKit is
    /// asked to retry fifteen minutes later.
    private func prefixRetainingError(
        at activation: Date,
        gregorianDay: GADay?,
        prefix: [TodayComplicationEntry]
    ) -> BuiltTimeline {
        var entries = prefix
        entries.append(errorEntry(at: activation, gregorianDay: gregorianDay))
        return BuiltTimeline(
            entries: entries,
            policy: .after(activation.addingTimeInterval(Self.errorRetryInterval))
        )
    }

    private func errorEntry(at activation: Date, gregorianDay: GADay?) -> TodayComplicationEntry {
        TodayComplicationEntry(
            date: activation,
            state: .day(watchCalculationErrorDisplay(gregorianDay: gregorianDay, settings: .watch))
        )
    }

    private func singleErrorTimeline(at instant: Date, gregorianDay: GADay?) -> BuiltTimeline {
        BuiltTimeline(
            entries: [errorEntry(at: instant, gregorianDay: gregorianDay)],
            policy: .after(instant.addingTimeInterval(Self.errorRetryInterval))
        )
    }
}
