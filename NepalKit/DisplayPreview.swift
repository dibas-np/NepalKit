// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Renders today's Bikram Sambat date with a given display configuration, for
/// the live preview in the Display section of Settings.
///
/// The two pickers above it change how every date in the app renders — menu
/// bar, popover, converter — and the preview closes that loop at the point of
/// change: the example sits under the controls and updates as they flip. It is
/// a function rather than view code so the wording and the nil behaviour are
/// pinned by tests, per the house rule that view logic lives where it can be
/// tested.
enum DisplayPreview {
    /// Today's date as the given settings would render it anywhere in the app,
    /// or nil when today sits outside the dataset's supported range. Nil rather
    /// than a substitute date: the preview exists to show what a *choice* looks
    /// like, and inventing a date to keep the row visible would show a rendering
    /// of nothing. The range itself is the About tab's fact to state.
    static func todayText(now: Date, in dataset: CalendarDataset, settings: DisplaySettings) -> String? {
        todayBS(now: now, in: dataset).map { formatBS($0, settings: settings) }
    }
}
