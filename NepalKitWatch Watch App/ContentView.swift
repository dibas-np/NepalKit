// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// Today, the Watch app's sole destination: the current Bikram Sambat date
/// for the Nepal Time day. Complication taps and app launch both land here.
struct ContentView: View {
    @State private var model = TodayModel()

    var body: some View {
        Text(model.displayText)
            .task { model.refresh() }
    }
}
