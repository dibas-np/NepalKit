// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import WidgetKit

/// One complication entry: when it activates and what it shows.
struct TodayComplicationEntry: TimelineEntry {
    let date: Date
    let state: TodayComplicationState
}
