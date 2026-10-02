// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit
import NepalKitCore

/// Renders a Today entry in whichever accessory family the face slot asks
/// for. The four accepted family compositions, their large-text fallbacks and
/// the full accessibility contract arrive with the presentation ticket; for
/// now every family shows the entry's state as one honest line so the
/// extension renders real resolved meaning.
struct TodayComplicationView: View {
    let entry: TodayComplicationEntry

    var body: some View {
        TodayComplicationContent(state: entry.state)
            .containerBackground(for: .widget) {
                // watchOS 10+ accessory widgets must declare their container
                // background; the complication supplies none of its own.
            }
    }
}

/// One line per state — the firm compact copy for boundary and failure, the
/// Bikram Sambat day and month for supported days.
struct TodayComplicationContent: View {
    let state: TodayComplicationState

    var body: some View {
        switch state {
        case .placeholder:
            Text("NepalKit")
        case .day(.supported(let components)):
            Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName)")
        case .day(.rangeBoundary):
            Text(WatchDayCopy.boundaryCompact)
        case .day(.calculationError):
            Text(WatchDayCopy.failureCompact)
        }
    }
}
