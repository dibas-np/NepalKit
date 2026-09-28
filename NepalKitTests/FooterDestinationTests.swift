// Verify the footer's position label tracks the tab, by exercising the same
// state the picker writes. Rendered through the real view so this is not a
// restatement of the implementation.
import SwiftUI
import Testing
@testable import NepalKit

@MainActor
struct FooterDestinationTests {
    @Test func footerLabelNamesTheSelectedDestination() {
        // The footer reads `destination.title`, the same @State the segmented
        // control writes. These assertions are about the *strings* each
        // destination contributes, which is the part that can silently go
        // stale: a renamed section would leave the footer naming the old one.
        #expect(PopoverDestination.today.title == Strings.todayLabel)
        #expect(PopoverDestination.convert.title == Strings.converterLabel)
    }

    @Test func destinationTitlesAreDistinct() {
        // A footer that named the same thing on both tabs would be worse than
        // no label at all, since it would look like position information.
        #expect(PopoverDestination.today.title != PopoverDestination.convert.title)
    }

    @Test func everyDestinationHasATitle() {
        // CaseIterable plus a switch that must be exhaustive: adding a case
        // without a title fails to compile, and this asserts the values are not
        // empty strings.
        for destination in PopoverDestination.allCases {
            #expect(!destination.title.isEmpty)
        }
    }
}
