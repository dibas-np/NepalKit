// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import WidgetKit
import NepalKitCore

/// One complication entry: the instant it activates and the Today line
/// resolved for it. Views render `label` without ever resolving a date.
///
/// The single-entry timeline is scaffolding for the provider ticket, which
/// replaces it with the fourteen-Gregorian-day horizon, boundary entries and
/// the failure policy.
struct TodayComplicationEntry: TimelineEntry {
    let date: Date
    /// The resolved Today line, or nil when the day lies outside the supported
    /// range (boundary states are expected results, not failures).
    let label: String?
}

/// Resolves Today through the shared core and dataset. The clock is injected
/// and read once per callback; nothing here touches MainActor isolation.
struct TodayComplicationProvider: TimelineProvider {
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date.now }) {
        self.now = now
    }

    /// Neutral and clock-free: WidgetKit redacts placeholders, so nothing here
    /// may imply a real Today.
    func placeholder(in context: Context) -> TodayComplicationEntry {
        TodayComplicationEntry(date: .distantPast, label: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayComplicationEntry) -> Void) {
        completion(entry(for: now()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayComplicationEntry>) -> Void) {
        completion(Timeline(entries: [entry(for: now())], policy: .atEnd))
    }

    private func entry(for instant: Date) -> TodayComplicationEntry {
        let label = todayBS(now: instant, in: .v2)
            .map { formatBS($0, settings: .watch) }
        return TodayComplicationEntry(date: instant, label: label)
    }
}
