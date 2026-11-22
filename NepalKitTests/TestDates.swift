// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import Testing
@testable import NepalKit

enum TestDates {
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    static let devanagariDigits: Set<Character> = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

    static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) throws -> Date {
        try #require(utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)))
    }
}

final class ScratchDefaults {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "NepalKitTests-\(UUID().uuidString)")

    func make() throws -> UserDefaults {
        // A named suite lands in ~/Library/Preferences, and cfprefsd rewrites its
        // plist after removePersistentDomain; an absolute path keeps it here instead.
        try #require(UserDefaults(suiteName: directory.appending(path: UUID().uuidString).path))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

extension MonthGridModel {
    static func kartik2083(
        festivals: FestivalCalendar = .panchanga,
        holidays: PublicHolidayCalendar = .gazette
    ) throws -> MonthGridModel {
        MonthGridModel(festivals: festivals, holidays: holidays, now: try TestDates.utc(2026, 10, 18, 6, 0))
    }

    static func baisakh2082() throws -> MonthGridModel {
        MonthGridModel(now: try TestDates.utc(2025, 4, 14, 6, 0))
    }

    var cells: [MonthGridDay] { weeks.flatMap { $0 }.compactMap { $0 } }

    var shownDays: [MonthGridDay] { cells.filter(\.isInShownMonth) }

    func shownDay(_ day: Int) throws -> MonthGridDay {
        try #require(shownDays.first { $0.bikramSambat.day == day })
    }
}
