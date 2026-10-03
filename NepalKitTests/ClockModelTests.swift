// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct ClockModelTests {

    private func model(at date: Date, local: String = "America/New_York") throws -> ClockModel {
        let zone = try #require(TimeZone(identifier: local))
        return ClockModel(now: date, localTimeZone: zone, refreshes: false)
    }

    @Test func bsDateFlipsAtNPTMidnight() throws {
        let before = try model(at: try TestDates.utc(2026, 9, 26, 18, 14))
        let after = try model(at: try TestDates.utc(2026, 9, 26, 18, 15))

        #expect(before.todayBSDate() == BSDay(year: 2083, month: 6, day: 10))
        #expect(after.todayBSDate() == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func gregorianAndBSStringsHonorSettings() throws {
        let clock = try model(at: try TestDates.utc(2026, 9, 27, 12, 0))
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

    @Test func weekdayHonorsMonthNameSetting() throws {
        // 27 Sep 2026 is a Sunday.
        let clock = try model(at: try TestDates.utc(2026, 9, 27, 12, 0))
        #expect(clock.weekdayString(style: .transliterated) == "Sunday")
        #expect(clock.weekdayString(style: .nepali) == "आइत")
    }

    @Test func nptClockTicksInNPTWithLocalAsReference() throws {
        // 18:30 UTC = 00:15 NPT next day, 14:30 in New York (EDT, UTC-4).
        let clock = try model(at: try TestDates.utc(2026, 9, 26, 18, 30))
        #expect(clock.nptTimeString(digits: .latin) == "00:15:00")
        #expect(clock.localTimeString(digits: .latin) == "14:30:00")
        #expect(clock.nptTimeString(digits: .devanagari) == "००:१५:००")
    }

    @Test func localTimeIsRedundantOnlyWhenTheReadingWouldRepeat() throws {
        // In Nepal, a second clock showing the same reading is noise.
        let inNepal = try model(at: try TestDates.utc(2026, 9, 27, 12, 0), local: "Asia/Kathmandu")
        #expect(inNepal.localTimeIsRedundant)
        // The readings are genuinely identical, not merely close.
        #expect(inNepal.localTimeString(digits: .latin) == inNepal.nptTimeString(digits: .latin))

        // Anywhere else the row earns its place.
        #expect(try !model(at: try TestDates.utc(2026, 9, 27, 12, 0)).localTimeIsRedundant)

        // Asia/Kolkata is UTC+5:30, a half hour from Nepal, and a plausible
        // thing for a Nepali speaker to be travelling in. Not redundant.
        #expect(try !model(at: try TestDates.utc(2026, 9, 27, 12, 0), local: "Asia/Kolkata").localTimeIsRedundant)
    }

    @Test func redundancyIsComparedByOffsetNotZoneIdentity() throws {
        // A fixed-offset zone at +05:45 shares Nepal's offset under a
        // different identifier. Identity comparison would call this
        // non-redundant and show a duplicated clock; offset comparison does not.
        let zone = try #require(TimeZone(secondsFromGMT: 20700))
        let offsetZone = ClockModel(
            now: try TestDates.utc(2026, 9, 27, 12, 0),
            localTimeZone: zone,
            refreshes: false
        )
        #expect(offsetZone.localTimeIsRedundant)
    }

    @Test func noForeignZoneEverSharesNepalsOffset() throws {
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
        let katmandu = try #require(TimeZone(identifier: "Asia/Katmandu"))
        let london = try #require(TimeZone(identifier: "Europe/London"))
        #expect(ClockModel(now: .now, localTimeZone: katmandu, refreshes: false).localTimeIsRedundant)
        #expect(!ClockModel(now: .now, localTimeZone: london, refreshes: false).localTimeIsRedundant)
    }

    @Test func localZoneFollowsAMidSessionSystemZoneChange() throws {
        var current = try #require(TimeZone(identifier: "Asia/Kathmandu"))
        let clock = ClockModel(now: try TestDates.utc(2026, 9, 27, 12, 0), systemZone: { current }, refreshes: false)

        #expect(clock.localTimeIsRedundant)

        current = try #require(TimeZone(identifier: "America/New_York"))
        #expect(!clock.localTimeIsRedundant)
        #expect(clock.localTimeString(digits: .latin) == "08:00:00")

        current = try #require(TimeZone(identifier: "Asia/Kathmandu"))
        #expect(clock.localTimeIsRedundant)
        #expect(clock.localTimeString(digits: .latin) == clock.nptTimeString(digits: .latin))
    }

    @Test func anInjectedZoneStillWinsOverTheSystemZone() throws {
        let systemZone = try #require(TimeZone(identifier: "America/New_York"))
        let localZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let clock = ClockModel(
            now: try TestDates.utc(2026, 9, 27, 12, 0),
            localTimeZone: localZone,
            systemZone: { systemZone },
            refreshes: false
        )
        #expect(clock.localTimeString(digits: .latin) == "17:30:00")
        #expect(clock.localTimeZone.identifier == "Asia/Kolkata")
    }

    @Test func defaultClockFollowsTheSystemZone() throws {
        let clock = ClockModel(now: try TestDates.utc(2026, 9, 27, 12, 0), refreshes: false)
        #expect(clock.localTimeZone.identifier == TimeZone.autoupdatingCurrent.identifier)
    }

    @Test func initializationSchedulesNoRefreshWork() {
        var reads = 0
        var sleeps = 0
        let initial = Date(timeIntervalSince1970: 0)
        let clock = ClockModel(now: initial, currentTime: {
            reads += 1
            return .now
        }, sleep: { _ in
            sleeps += 1
        })

        #expect(clock.now == initial)
        #expect(reads == 0)
        #expect(sleeps == 0)
    }

    @Test func visibleRefreshStopsOnCancellationAndRestartsFromCurrentTime() async throws {
        var instant = try TestDates.utc(2026, 9, 26, 18, 14)
        var reads = 0
        var sleeps = 0
        var task: Task<Void, Never>?
        let clock = ClockModel(currentTime: {
            reads += 1
            return instant
        }, sleep: { interval in
            #expect(interval == .seconds(1))
            sleeps += 1
            instant = instant.addingTimeInterval(60)
            if sleeps.isMultiple(of: 2) {
                task?.cancel()
            }
        })

        task = Task { await clock.refreshWhileVisible() }
        await task?.value
        #expect(reads == 2)
        #expect(sleeps == 2)
        #expect(clock.todayBSDate() == BSDay(year: 2083, month: 6, day: 11))

        // Simulate a long closed interval; reopening reads the new instant.
        instant = try TestDates.utc(2026, 9, 28, 12, 0)
        task = Task { await clock.refreshWhileVisible() }
        await task?.value
        #expect(reads == 4)
        #expect(sleeps == 4)
        #expect(clock.todayADDate() == GADay(year: 2026, month: 9, day: 28))
        task = nil
    }

    @Test func cancellationBeforeAppearanceDoesNotReadOrSchedule() async {
        var reads = 0
        var sleeps = 0
        let clock = ClockModel(currentTime: {
            reads += 1
            return .now
        }, sleep: { _ in
            sleeps += 1
        })
        let task = Task { await clock.refreshWhileVisible() }
        task.cancel()
        await task.value

        #expect(reads == 0)
        #expect(sleeps == 0)
    }

    @Test func fixedPreviewDoesNotRefreshWhenVisible() async throws {
        let instant = try TestDates.utc(2026, 9, 27, 12, 0)
        let clock = ClockModel(now: instant, refreshes: false, currentTime: {
            Issue.record("A fixed clock must not read the live time")
            return .now
        }, sleep: { _ in
            Issue.record("A fixed clock must not schedule refresh work")
        })
        await clock.refreshWhileVisible()
        #expect(clock.now == instant)
    }
}
