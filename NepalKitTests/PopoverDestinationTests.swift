// The strings the popover's destination tabs (DestinationTabs) show for each
// destination.
import SwiftUI
import Testing
@testable import NepalKit

@MainActor
struct PopoverDestinationTests {
    @Test func segmentTitlesNameTheirDestinations() {
        // A renamed section would otherwise leave a tab naming the old one.
        #expect(PopoverDestination.today.title == Strings.todayLabel)
        #expect(PopoverDestination.convert.title == Strings.converterLabel)
    }

    @Test func destinationTitlesAreDistinct() {
        // Two tabs with the same title couldn't be told apart.
        #expect(PopoverDestination.today.title != PopoverDestination.convert.title)
    }

    @Test func everyDestinationHasATitle() {
        // The exhaustive switch catches a missing title at compile time; this
        // catches an empty one.
        for destination in PopoverDestination.allCases {
            #expect(!destination.title.isEmpty)
        }
    }
}
