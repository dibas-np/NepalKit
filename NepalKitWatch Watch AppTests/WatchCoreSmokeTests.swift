// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import NepalKitWatchSupport

struct WatchCoreSmokeTests {
    private let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test func watchContextResolvesBikramSambatThroughTheSharedDataset() throws {
        let now = try anchoredInstant()

        #expect(BikramSambatDate.today(now: now, in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test func watchContextRendersTheFixedCanonicalSettings() throws {
        let now = try anchoredInstant()

        #expect(BikramSambatDate.today(now: now, in: .v2).map { ($0).formatted(.watch) } == "११ असोज २०८३")
    }

    private func anchoredInstant() throws -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 26
        components.hour = 18
        components.minute = 30
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return try #require(utcGregorian.date(from: components))
    }
}
