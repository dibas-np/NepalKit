// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import NepalKitWatchSupport

enum TodayComplicationState: Sendable, Hashable {
    case placeholder
    case day(WatchDayDisplay)
}
