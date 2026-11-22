// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit

/// The Today complication, in all four accessory families.
struct TodayComplication: Widget {
    /// Renaming this removes placed complications from users' faces.
    nonisolated static let kind = "NepalKitTodayComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: makeTodayProvider()) { entry in
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

#if NEPALKIT_WATCH_FIXTURES
private func makeTodayProvider() -> TodayComplicationProvider {
    ComplicationFixtures.makeProvider()
}
#else
private func makeTodayProvider() -> TodayComplicationProvider {
    TodayComplicationProvider()
}
#endif
