// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import WidgetKit

/// One complication entry: the instant it activates and the complete display
/// meaning core resolved for that day. Views render `state`; they never read
/// a clock or resolve a date.
struct TodayComplicationEntry: TimelineEntry {
    let date: Date
    let state: TodayComplicationState
}
