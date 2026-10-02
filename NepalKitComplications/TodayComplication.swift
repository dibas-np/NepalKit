// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit

/// The Today complication: one static configuration across all four accessory
/// families. Tapping it opens the Watch app, whose sole destination is Today.
struct TodayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NepalKitTodayComplication", provider: TodayComplicationProvider()) { entry in
            TodayComplicationView(entry: entry)
        }
        .configurationDisplayName("Today in Bikram Sambat")
        .description("Today's Bikram Sambat date for the Nepal Time day.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
            .accessoryCorner,
        ])
    }
}
