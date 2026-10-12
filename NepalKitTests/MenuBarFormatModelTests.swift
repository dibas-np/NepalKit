// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// Nepal Time is UTC+5:45, so a whole UTC minute is a whole Nepal Time minute.
struct TimeTickIntervalTests {
    @Test func minuteTickWaitsForTheNextMinuteBoundary() throws {
        // 05:12:07 UTC is 10:57:07 Nepal Time: 53 s to 10:58:00.
        let interval = MenuBarModel.timeTickInterval(after: try TestDates.utc(2026, 9, 27, 5, 12, 7), showsSeconds: false)
        #expect(interval == 53)
    }

    @Test func onABoundaryTheTickWaitsAWholePeriod() throws {
        let boundary = try TestDates.utc(2026, 9, 27, 5, 12, 0)
        #expect(MenuBarModel.timeTickInterval(after: boundary, showsSeconds: false) == 60)
        #expect(MenuBarModel.timeTickInterval(after: boundary, showsSeconds: true) == 1)
    }

    @Test func secondTickWaitsForTheNextSecondBoundary() throws {
        let quarterPast = try TestDates.utc(2026, 9, 27, 5, 12, 7).addingTimeInterval(0.25)
        #expect(MenuBarModel.timeTickInterval(after: quarterPast, showsSeconds: true) == 0.75)
    }

    @Test func instantsBeforeTheReferenceDateStillAlign() {
        // -30010 s from 2001-01-01 UTC is 2000-12-31 21:24:50 Nepal Time, 10 s
        // short of a minute; the raw remainder there is negative.
        let interval = MenuBarModel.timeTickInterval(after: Date(timeIntervalSinceReferenceDate: -30_010), showsSeconds: false)
        #expect(interval == 10)
    }
}

/// The format as the menu-bar model applies, persists and ticks for it.
/// 12:00 UTC on 27 Sep 2026 is 17:45 Nepal Time on Sunday, 11 Ashoj 2083.
@MainActor
struct MenuBarFormatModelTests {
    private static let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private static let everything = MenuBarFormat(showsWeekday: true, showsYear: true, showsTime: true)

    private func freshStore() throws -> (SettingsStore, UserDefaults) {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(defaults: defaults), defaults)
    }

    private func fixedModel(store: SettingsStore? = nil) throws -> MenuBarModel {
        MenuBarModel(now: try TestDates.utc(2026, 9, 27, 12, 0), refreshes: false, schedulesMidnightFire: false, store: store)
    }

    private func refreshingModel(store: SettingsStore? = nil) throws -> MenuBarModel {
        MenuBarModel(
            now: try TestDates.utc(2026, 9, 27, 12, 0),
            schedulesMidnightFire: false,
            store: store,
            workspaceNotifications: RecordingCenter(),
            systemNotifications: RecordingCenter()
        )
    }

    @Test func withoutAStoreTheTitleIsUnchanged() throws {
        let model = try fixedModel()
        #expect(model.format == .standard)
        #expect(model.title(settings: Self.latin) == "11 Ashoj")
    }

    @Test func savingAFormatChangesTheTitleAtOnce() throws {
        let model = try fixedModel()

        model.save(Self.everything)

        #expect(model.title(settings: Self.latin) == "Sun 11 Ashoj 2083 5:45")
        #expect(model.title(settings: DisplaySettings(digits: .devanagari, monthNames: .nepali)) == "आइत ११ असोज २०८३ ५:४५")
    }

    @Test func bindingTargetsEditOnePartEach() throws {
        let model = try fixedModel()

        model.showsWeekday = true
        #expect(model.title(settings: Self.latin) == "Sun 11 Ashoj")
        model.showsYear = true
        model.showsTime = true
        model.usesTwentyFourHourClock = true
        #expect(model.title(settings: Self.latin) == "Sun 11 Ashoj 2083 17:45")
        model.showsSeconds = true
        #expect(model.title(settings: Self.latin) == "Sun 11 Ashoj 2083 17:45:00")
        #expect([model.showsWeekday, model.showsYear, model.showsTime, model.usesTwentyFourHourClock, model.showsSeconds] == [true, true, true, true, true])
        model.showsTime = false
        #expect(model.title(settings: Self.latin) == "Sun 11 Ashoj 2083")
    }

    @Test func updateMarkerStillPrefixesTheWholeTitle() throws {
        let model = try fixedModel()
        model.save(Self.everything)

        #expect(model.title(settings: Self.latin, updateAvailable: true) == "! Sun 11 Ashoj 2083 5:45")
    }

    @Test func beyondTheRangeTheMarkerReplacesTheTimeToo() {
        // 26 Jul 2028, past the table's 12 April 2028 end.
        let model = MenuBarModel(now: Date(timeIntervalSince1970: 1_848_096_000), refreshes: false, schedulesMidnightFire: false)
        model.save(Self.everything)

        #expect(model.title(settings: Self.latin) == Strings.menuBarBeyondRange)
        #expect(model.spokenTitle(settings: Self.latin).contains("calendar data ends"))
    }

    @Test func spokenTitleCarriesTheChosenPartsPronounceably() throws {
        let model = try fixedModel()
        model.save(MenuBarFormat(showsWeekday: true, showsTime: true, usesTwentyFourHourClock: true))
        let devanagari = DisplaySettings(digits: .devanagari, monthNames: .transliterated)

        #expect(model.spokenTitle(settings: devanagari) == "NepalKit, Sunday, 11 Ashoj 2083, 17:45")
        #expect(model.spokenTitle(settings: devanagari, updateAvailable: true) == "NepalKit, update available, Sunday, 11 Ashoj 2083, 17:45")
    }

    @Test func formatPersistsAndIsReadBackByTheNextModel() throws {
        let (store, defaults) = try freshStore()
        let model = try fixedModel(store: store)

        model.showsWeekday = true
        model.showsTime = true
        model.showsSeconds = true

        let expected = MenuBarFormat(showsWeekday: true, showsTime: true, showsSeconds: true)
        #expect(SettingsStore(defaults: defaults).menuBarFormat == expected)
        #expect(try fixedModel(store: SettingsStore(defaults: defaults)).format == expected)
    }

    @Test func timeTickRunsOnlyWhileTheTimeIsShown() throws {
        let model = try refreshingModel()
        #expect(!model.isTickingForTime)

        model.showsTime = true
        #expect(model.isTickingForTime)
        model.showsSeconds = true
        #expect(model.isTickingForTime)
        model.showsTime = false
        #expect(!model.isTickingForTime)
    }

    @Test func aStoredTimeFormatTicksFromLaunch() throws {
        let (store, _) = try freshStore()
        store.save(MenuBarFormat(showsTime: true))

        #expect(try refreshingModel(store: store).isTickingForTime)
    }

    @Test func aModelThatDoesNotRefreshNeverTicks() throws {
        let model = try fixedModel()
        model.showsTime = true

        #expect(!model.isTickingForTime)
        #expect(model.now == (try TestDates.utc(2026, 9, 27, 12, 0)))
    }

    @Test func savingRereadsTheClockSoTheTimeIsNotStale() throws {
        let stale = try TestDates.utc(2026, 9, 27, 12, 0)
        let model = try refreshingModel()

        model.showsTime = true

        #expect(model.now > stale)
    }

    @Test func clockDiscontinuityKeepsTheTickRunning() throws {
        let model = try refreshingModel()
        model.showsTime = true

        model.refreshAfterClockDiscontinuity()

        #expect(model.isTickingForTime)
    }
}
