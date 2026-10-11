// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The popover's destinations as a row of quiet tabs: an icon and a name each,
/// the selected one on a soft capsule, the rest plain.
///
/// Replaces the segmented control, which drew every option inside one bordered
/// bar and read as a form control at the top of a reading surface. A row of
/// labels also grows: a third or fourth destination adds a tab, where a
/// segmented control would have squeezed every segment narrower.
struct DestinationTabs: View {
    @Binding var selection: PopoverDestination
    @Namespace private var capsule

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PopoverDestination.allCases, id: \.self) { destination in
                let isSelected = destination == selection
                Button {
                    selection = destination
                } label: {
                    Label(destination.title, systemImage: destination.symbol)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if isSelected {
                                // One capsule that moves between tabs, rather
                                // than one per tab fading in and out.
                                Capsule()
                                    .fill(.quaternary)
                                    .matchedGeometryEffect(id: "selected", in: capsule)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .symbolRenderingMode(.monochrome)
        .animation(.snappy, value: selection)
        // A choice between views, named so VoiceOver says what the buttons
        // choose between rather than reading three unrelated buttons.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Strings.popoverDestinationsLabel)
    }
}
