// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Today's date rendered with the given settings, for the Display section's preview.
enum DisplayPreview {
    /// Nil when today is outside the supported range.
    static func todayText(
        now: Date,
        timeZone: TimeZone = .nepal,
        in dataset: CalendarDataset,
        settings: DisplaySettings
    ) -> String? {
        BikramSambatDate.today(now: now, timeZone: timeZone, in: dataset).map { ($0).formatted(settings) }
    }
}
