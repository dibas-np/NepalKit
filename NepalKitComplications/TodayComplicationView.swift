// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit

/// Renders a Today entry in whichever accessory family the face slot asks
/// for. Family-specific compositions and large-text fallbacks arrive with the
/// presentation ticket; the scaffold keeps every family on one line so the
/// extension compiles and renders with the shared dataset.
struct TodayComplicationView: View {
    let entry: TodayComplicationEntry

    var body: some View {
        Text(entry.label ?? "NepalKit")
            .containerBackground(for: .widget) {
                // watchOS 10+ accessory widgets must declare their container
                // background; the complication supplies none of its own.
            }
    }
}
