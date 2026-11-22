// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

enum DisplayPreview {
    static func todayText(
        now: Date,
        timeZone: TimeZone = .nepal,
        in dataset: CalendarDataset,
        settings: DisplaySettings
    ) -> String? {
        BikramSambatDate.today(now: now, timeZone: timeZone, in: dataset).map { ($0).formatted(settings) }
    }
}
