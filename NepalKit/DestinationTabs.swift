// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The popover's destinations as a row of quiet tabs, the selected one on a
/// soft capsule. Not a segmented control: that reads as a form control and
/// squeezes every segment narrower as destinations are added.
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
                                // One capsule that moves between tabs.
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
        // Named and announced as a tab bar, not as unrelated buttons.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Strings.popoverDestinationsLabel)
        .accessibilityAddTraits(.isTabBar)
    }
}
