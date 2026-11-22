// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import WidgetKit

struct TodayComplicationEntry: TimelineEntry {
    let date: Date
    let state: TodayComplicationState
}
