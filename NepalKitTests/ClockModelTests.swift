// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct ClockModelTests {

    private func model(at date: Date, local: String = "America/New_York") -> ClockModel {
        ClockModel(now: date, localTimeZone: TimeZone(identifier: local)!, refreshInterval: 3600)
    }

    @Test func bsDateFlipsAtNPTMidnight() {
        let before = model(at: TestDates.utc(2026, 9, 26, 18, 14))
        let after = model(at: TestDates.utc(2026, 9, 26, 18, 15))

        #expect(before.todayBSDate() == BSDay(year: 2083, month: 6, day: 10))
        #expect(after.todayBSDate() == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func gregorianAndBSStringsHonorSettings() throws {
        let clock = model(at: TestDates.utc(2026, 9, 27, 12, 0))
        let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
        let devanagari = DisplaySettings(digits: .devanagari, monthNames: .nepali)

        // Through the same formatters the views use, so the test describes
        // what renders rather than a parallel path.
        let bs = try #require(clock.todayBSDate())
        #expect(formatBS(bs, settings: latin) == "11 Ashoj 2083")
        #expect(formatBS(bs, settings: devanagari) == "११ असोज २०८३")
        let ad = try #require(clock.todayADDate())
        #expect(formatAD(ad, settings: latin) == "27 September 2026")
        #expect(formatAD(ad, settings: devanagari) == "२७ September २०२६")
    }

    @Test func weekdayHonorsMonthNameSetting() {
        // 27 Sep 2026 is a Sunday.
        let clock = model(at: TestDates.utc(2026, 9, 27, 12, 0))
        #expect(clock.weekdayString(style: .transliterated) == "Sunday")
        #expect(clock.weekdayString(style: .nepali) == "आइत")
    }

    @Test func nptClockTicksInNPTWithLocalAsReference() {
        // 18:30 UTC = 00:15 NPT next day, 14:30 in New York (EDT, UTC-4).
        let clock = model(at: TestDates.utc(2026, 9, 26, 18, 30))
        #expect(clock.nptTimeString(digits: .latin) == "00:15:00")
        #expect(clock.localTimeString(digits: .latin) == "14:30:00")
        #expect(clock.nptTimeString(digits: .devanagari) == "००:१५:००")
    }

    @Test func localTimeIsRedundantOnlyWhenTheReadingWouldRepeat() {
        // In Nepal, a second clock showing the same reading is noise.
        let inNepal = model(at: TestDates.utc(2026, 9, 27, 12, 0), local: "Asia/Kathmandu")
        #expect(inNepal.localTimeIsRedundant)
        // The readings are genuinely identical, not merely close.
        #expect(inNepal.localTimeString(digits: .latin) == inNepal.nptTimeString(digits: .latin))

        // Anywhere else the row earns its place.
        #expect(!model(at: TestDates.utc(2026, 9, 27, 12, 0)).localTimeIsRedundant)

        // Asia/Kolkata is UTC+5:30, a half hour from Nepal, and a plausible
        // thing for a Nepali speaker to be travelling in. Not redundant.
        #expect(!model(at: TestDates.utc(2026, 9, 27, 12, 0), local: "Asia/Kolkata").localTimeIsRedundant)
    }

    @Test func redundancyIsComparedByOffsetNotZoneIdentity() {
        // A fixed-offset zone at +05:45 shares Nepal's offset under a
        // different identifier. Identity comparison would call this
        // non-redundant and show a duplicated clock; offset comparison does not.
        let offsetZone = ClockModel(
            now: TestDates.utc(2026, 9, 27, 12, 0),
            localTimeZone: TimeZone(secondsFromGMT: 20700)!,
            refreshInterval: 3600
        )
        #expect(offsetZone.localTimeIsRedundant)
    }

    @Test func noForeignZoneEverSharesNepalsOffset() {
        // Pins why the offset comparison cannot be reduced to a DST case.
        // Nepal is +05:45, a half-hour offset, and a scan of every zone in the
        // database at two instants finds only Nepal's own two spellings. So
        // "is the local zone a DST zone that happens to match" has no cases, and
        // the only redundant readings are genuinely Nepal's own — which is the
        // situation the popover is hiding the row for.
        //
        // The two spellings are the point: they are distinct TimeZone values
        // that both resolve to +05:45, so an identity comparison against
        // `nepalTimeZone` would miss `Asia/Katmandu` entirely.
        #expect(ClockModel(now: .now, localTimeZone: TimeZone(identifier: "Asia/Katmandu")!, refreshInterval: 3600).localTimeIsRedundant)
        #expect(!ClockModel(now: .now, localTimeZone: TimeZone(identifier: "Europe/London")!, refreshInterval: 3600).localTimeIsRedundant)
    }

    @Test func localZoneFollowsAMidSessionSystemZoneChange() {
        var current = TimeZone(identifier: "Asia/Kathmandu")!
        let clock = ClockModel(now: TestDates.utc(2026, 9, 27, 12, 0), systemZone: { current }, refreshInterval: 3600)

        #expect(clock.localTimeIsRedundant)

        current = TimeZone(identifier: "America/New_York")!
        #expect(!clock.localTimeIsRedundant)
        #expect(clock.localTimeString(digits: .latin) == "08:00:00")

        current = TimeZone(identifier: "Asia/Kathmandu")!
        #expect(clock.localTimeIsRedundant)
        #expect(clock.localTimeString(digits: .latin) == clock.nptTimeString(digits: .latin))
    }

    @Test func anInjectedZoneStillWinsOverTheSystemZone() {
        let clock = ClockModel(
            now: TestDates.utc(2026, 9, 27, 12, 0),
            localTimeZone: TimeZone(identifier: "Asia/Kolkata")!,
            systemZone: { TimeZone(identifier: "America/New_York")! },
            refreshInterval: 3600
        )
        #expect(clock.localTimeString(digits: .latin) == "17:30:00")
        #expect(clock.localTimeZone.identifier == "Asia/Kolkata")
    }

    @Test func defaultClockFollowsTheSystemZone() {
        let clock = ClockModel(now: TestDates.utc(2026, 9, 27, 12, 0), refreshInterval: 3600)
        #expect(clock.localTimeZone.identifier == TimeZone.autoupdatingCurrent.identifier)
    }
}
