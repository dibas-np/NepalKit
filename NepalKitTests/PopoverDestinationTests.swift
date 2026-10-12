// The strings the popover's segmented control shows for each destination, the
// only place these titles appear.
import SwiftUI
import Testing
@testable import NepalKit

@MainActor
struct PopoverDestinationTests {
    @Test func segmentTitlesNameTheirDestinations() {
        // The segments read `destination.title`; a renamed section would
        // otherwise leave the control silently naming the old one.
        #expect(PopoverDestination.today.title == Strings.todayLabel)
        #expect(PopoverDestination.convert.title == Strings.converterLabel)
    }

    @Test func destinationTitlesAreDistinct() {
        // Two segments with the same title could not be told apart, by eye or
        // by VoiceOver.
        #expect(PopoverDestination.today.title != PopoverDestination.convert.title)
    }

    @Test func everyDestinationHasATitle() {
        // The exhaustive switch catches a missing title at compile time; this
        // catches an empty one.
        for destination in PopoverDestination.allCases {
            #expect(!destination.title.isEmpty)
        }
    }

    @Test func everyDestinationHasItsOwnSymbol() {
        #expect(PopoverDestination.today.symbol == Symbols.today)
        #expect(PopoverDestination.convert.symbol == Symbols.converter)
        let symbols = PopoverDestination.allCases.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
        #expect(symbols.allSatisfy(Symbols.all.contains))
    }
}
