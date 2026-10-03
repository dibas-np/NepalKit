// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// Proves the shared compiled dataset answers inside a watchOS test runner:
/// the same compiled table the Mac links, exercised through the Watch app's
/// core dependency, offline and without any Watch-specific copy of the data.
///
/// This bundle also compiles `NepalKitComplications/`, so it carries the
/// extension's `nonisolated` default rather than the Watch app's `MainActor`
/// and the two copies of those sources agree by setting, not by luck.
///
/// The anchored instant and expected Bikram Sambat date reuse the
/// authoritative pair the host `TodayTests` suite already pins (26 September
/// 2026, 18:30 UTC = 11 Ashoj 2083); nothing here invents its own fixture.
struct WatchCoreSmokeTests {
    private let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test func watchContextResolvesBikramSambatThroughTheSharedDataset() throws {
        let now = try anchoredInstant()

        #expect(todayBS(now: now, in: .v2) == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func watchContextRendersTheFixedCanonicalSettings() throws {
        let now = try anchoredInstant()

        #expect(todayBS(now: now, in: .v2).map { formatBS($0, settings: .watch) } == "११ असोज २०८३")
    }

    /// 26 September 2026, 18:30 UTC — already 11 Ashoj 2083 in Nepal Time.
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
