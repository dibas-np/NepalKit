// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit

/// The Today complication: one static configuration across all four accessory
/// families. Tapping it opens the Watch app, whose sole destination is Today.
struct TodayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NepalKitTodayComplication", provider: makeTodayProvider()) { entry in
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

/// The provider factory: ordinary in every nondevelopment build, fixture-wired
/// only when the development condition is compiled in.
#if NEPALKIT_WATCH_FIXTURES
private func makeTodayProvider() -> TodayComplicationProvider {
    ComplicationFixtures.makeProvider()
}
#else
private func makeTodayProvider() -> TodayComplicationProvider {
    TodayComplicationProvider()
}
#endif
