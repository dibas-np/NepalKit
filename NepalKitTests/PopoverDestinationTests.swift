// Verify the strings the popover's segmented control shows for each
// destination. The footer no longer names the destination, so the control is
// the one place these titles appear.
import SwiftUI
import Testing
@testable import NepalKit

@MainActor
struct PopoverDestinationTests {
    @Test func segmentTitlesNameTheirDestinations() {
        // The segments read `destination.title`. These assertions are about the
        // *strings* each destination contributes, which is the part that can
        // silently go stale: a renamed section would leave the control naming
        // the old one.
        #expect(PopoverDestination.today.title == Strings.todayLabel)
        #expect(PopoverDestination.convert.title == Strings.converterLabel)
    }

    @Test func destinationTitlesAreDistinct() {
        // Two segments with the same title could not be told apart, by eye or
        // by VoiceOver.
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
