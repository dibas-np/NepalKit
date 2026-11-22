// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel

/// A public holiday on a Bikram Sambat date, as the Home Ministry's notice in
/// the Nepal Gazette lists it. Holidays and festivals do not line up one to
/// one: Dashain is a week of holidays and one Tika day.
public struct PublicHoliday: Hashable, Sendable {
    /// Who the holiday is for.
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
    /// An English name, set only for days of a holiday range (Dashain, Tihar)
    /// that have no festival of their own.
    public let english: String?

    public init(scope: Scope, nepali: String, english: String? = nil) {
        self.scope = scope
        self.nepali = nepali
        self.english = english
    }
}

/// Public holidays by Bikram Sambat date, for the years whose gazette notice
/// has been read.
public struct PublicHolidayCalendar: Sendable {
    /// Years with holiday data. A missing year is a gap, not a year without
    /// holidays.
    public let years: Set<Int>
    let entries: [BikramSambatDate: [PublicHoliday]]

    public init(years: Set<Int>, entries: [BikramSambatDate: [PublicHoliday]]) {
        self.years = years
        self.entries = entries
    }

    /// The gazette's rows for `day`, in its order. Several rows can share a
    /// scope; use `scopes(on:)` for display.
    public func holidays(on day: BikramSambatDate) -> [PublicHoliday] {
        entries[day] ?? []
    }

    /// The distinct scopes of `day`'s holidays, in order of first appearance.
    public func scopes(on day: BikramSambatDate) -> [PublicHoliday.Scope] {
        var seen: Set<PublicHoliday.Scope> = []
        return holidays(on: day).map(\.scope).filter { seen.insert($0).inserted }
    }

    /// Whether `day` is a nationwide holiday.
    public func isNationwideHoliday(_ day: BikramSambatDate) -> Bool {
        holidays(on: day).contains { $0.scope == .nationwide }
    }

    /// What to name `day` by: its festivals, or the gazette's holiday name
    /// when it has none, so a holiday is never unnamed.
    public func observances(on day: BikramSambatDate, festivals: FestivalCalendar) -> [Festival] {
        let own = festivals.festivals(on: day)
        guard own.isEmpty else { return own }
        var seen: Set<String> = []
        return holidays(on: day).compactMap { holiday in
            guard let english = holiday.english, seen.insert(holiday.nepali).inserted else { return nil }
            return Festival(nepali: holiday.nepali, english: english, source: .gazette)
        }
    }

    /// Every entry, for checks that sweep the table.
    public var allEntries: [(day: BikramSambatDate, holidays: [PublicHoliday])] {
        entries.map { ($0.key, $0.value) }
    }

    /// The bundled calendar: every gazette notice read so far.
    public static let gazette = PublicHolidayCalendar(years: [2083], entries: publicHolidays2083)
}
