// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import Testing
@testable import NepalKit

@MainActor
struct PopoverDestinationTests {
    @Test func segmentTitlesNameTheirDestinations() {
        #expect(PopoverDestination.today.title == Strings.todayLabel)
        #expect(PopoverDestination.convert.title == Strings.converterLabel)
    }

    @Test func destinationTitlesAreDistinct() {
        #expect(PopoverDestination.today.title != PopoverDestination.convert.title)
    }

    @Test func everyDestinationHasATitle() {
        for destination in PopoverDestination.allCases {
            #expect(!destination.title.isEmpty)
        }
    }
}
