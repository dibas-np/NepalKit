// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// A public holiday on a Bikram Sambat date, as the Home Ministry's notice in
/// the Nepal Gazette lists it. Separate from `Festival`: the Panchanga says
/// what is observed, the gazette says who gets the day off, and the two do
/// not line up one to one (Dashain is a week of holidays and one Tika day).
public struct PublicHoliday: Hashable, Sendable {
    /// Who the holiday is for. Most are nationwide; the gazette limits the
    /// rest to a community, a region or a group of employees.
    public enum Scope: Hashable, Sendable, CaseIterable {
        case nationwide
        case newarCommunity
        case kathmanduValley
        case womenEmployees
        /// Only women employees who observe Jitiya: narrower than Teej's.
        case womenObservingJitiya
        case educationalInstitutions
        case hillAndMountainDistricts
        case taraiDistricts
        case duraCommunity
        case employeesWithDisabilities
        case kiratCommunity
        case sikhCommunity
        /// Where Gaura Parva is observed; the gazette names no districts.
        case gauraRegion
    }

    public let scope: Scope
    /// The gazette's own wording, in Devanagari.
    public let nepali: String

    public init(scope: Scope, nepali: String) {
        self.scope = scope
        self.nepali = nepali
    }
}

/// Public holidays by Bikram Sambat date, for the years whose gazette notice
/// has been read.
public struct PublicHolidayCalendar: Sendable {
    /// Years with holiday data. A year outside this set has none yet, which is
    /// a gap, not a year without holidays.
    public let years: Set<Int>
    let entries: [BSDay: [PublicHoliday]]

    public init(years: Set<Int>, entries: [BSDay: [PublicHoliday]]) {
        self.years = years
        self.entries = entries
    }

    /// The gazette's rows for `day`, in its order. One day can have several
    /// rows of the same scope (18 Baisakh is three nationwide items), so a
    /// reader wants `scopes(on:)`; this keeps the table as it was read.
    public func holidays(on day: BSDay) -> [PublicHoliday] {
        entries[day] ?? []
    }

    /// The distinct scopes of `day`'s holidays, in the order they first
    /// appear: what to show, since three nationwide rows are one day off.
    public func scopes(on day: BSDay) -> [PublicHoliday.Scope] {
        var seen: Set<PublicHoliday.Scope> = []
        return holidays(on: day).map(\.scope).filter { seen.insert($0).inserted }
    }

    /// Whether `day` is a holiday for everyone, as opposed to one limited to
    /// a community, region or group.
    public func isNationwideHoliday(_ day: BSDay) -> Bool {
        holidays(on: day).contains { $0.scope == .nationwide }
    }

    /// Every entry, for checks that sweep the table.
    public var allEntries: [(day: BSDay, holidays: [PublicHoliday])] {
        entries.map { ($0.key, $0.value) }
    }

    /// The bundled calendar: every gazette notice read so far.
    public static let gazette = PublicHolidayCalendar(years: [2083], entries: publicHolidays2083)
}
