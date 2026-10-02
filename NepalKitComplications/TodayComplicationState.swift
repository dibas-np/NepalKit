// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// What one complication entry renders.
enum TodayComplicationState: Sendable, Hashable {
    /// Clock-free neutral content for the placeholder. WidgetKit redacts
    /// placeholder content, so nothing here may imply a real Today.
    case placeholder
    /// A supported day, an expected range boundary, or a calculation failure
    /// — the complete meaning core supplied for one day.
    case day(WatchDayDisplay)
}
