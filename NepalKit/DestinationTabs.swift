// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

struct DestinationTabs: View {
    @Binding var selection: PopoverDestination

    var body: some View {
        Picker(Strings.popoverDestinationsLabel, selection: $selection) {
            ForEach(PopoverDestination.allCases, id: \.self) { destination in
                Text(destination.title)
                    .tag(destination)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
