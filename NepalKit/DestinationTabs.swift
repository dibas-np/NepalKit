// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The popover's destinations as the system segmented control.
///
/// It used to be a hand-drawn row of tabs on a soft capsule, kept apart from a
/// segmented control because that read as a form control. Apple's macOS 27 kit
/// settles it the other way: its segmented control is a capsule track with the
/// selection raised inside it, which is exactly what the custom row
/// imitated. The custom row also sat directly above the
/// converter's own segmented control, so the popover showed two selection
/// idioms one above the other.
///
/// Text only, as the kit's segments are, and sized to its labels like the
/// converter's direction control below it, so the two read as one family.
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
