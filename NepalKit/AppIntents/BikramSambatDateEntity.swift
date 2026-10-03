// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// A Bikram Sambat date as Shortcuts sees it (ticket 03's structured return).
///
/// The fields an automation can read — year, month, day, weekday — while the
/// display title is the *shown* half of the dialog/display split: rendered
/// with the user's actual display settings, Devanagari digits included. The
/// dialog an intent pairs with this entity stays in `SpokenDate` form.
nonisolated struct BikramSambatDateEntity: AppEntity, Hashable, Sendable {
    private let date: BSDay
    private let calendarMonth: BikramSambatMonth
    private let weekdayValue: String?

    @ComputedProperty(title: "Year")
    var year: Int { date.year }

    @ComputedProperty(title: "Month")
    var month: BikramSambatMonth { calendarMonth }

    @ComputedProperty(title: "Day")
    var day: Int { date.day }

    @ComputedProperty(title: "Weekday")
    var weekday: String? { weekdayValue }

    // Macro-generated property storage is not Hashable; compare calendar values.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date && lhs.weekdayValue == rhs.weekdayValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(weekdayValue)
    }

    /// Stable text identity: the Bikram Sambat date it names.
    var id: String { "\(year)-\(month.rawValue)-\(day)" }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bikram Sambat date")

    static let defaultQuery = BikramSambatDateQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(formatBS(bsDay, settings: SettingsStore().settings))")
    }

    /// The dataset-world day this entity names.
    var bsDay: BSDay { date }

    /// Validates the calendar day and supplies its weekday for every query path.
    init?(bsDay: BSDay, weekday: String? = nil) {
        guard let month = BikramSambatMonth(rawValue: bsDay.month),
              let gregorian = bsToAD(bsDay, in: AppData.dataset) else { return nil }
        self.date = bsDay
        self.calendarMonth = month
        self.weekdayValue = weekday ?? IntentAnswers.weekdayNameString(NepalKitCore.weekday(of: gregorian))
    }

    /// Today's date, anchored to Nepal Time. Nil once the current date passes
    /// the supported range — the caller speaks the boundary statement then.
    static func today() -> BikramSambatDateEntity? {
        guard let bs = todayBS(now: Date(), in: AppData.dataset) else { return nil }
        return BikramSambatDateEntity(bsDay: bs)
    }

    /// Best-effort parse of a typed string like "15 Ashar 2082" — the month
    /// token must equal a title or synonym exactly (case-insensitive; Latin
    /// and Devanagari), and the two integers in the string are read as day
    /// and year. Only Latin digits are parsed; typed Devanagari input is
    /// accepted by the live Shortcuts UI pickers instead.
    static func parsing(_ string: String) -> BikramSambatDateEntity? {
        var month: BikramSambatMonth?
        var numbers: [Int] = []
        for rawToken in string.split(whereSeparator: \.isWhitespace) {
            let token = String(rawToken)
            if let value = Int(token), value > 0 {
                numbers.append(value)
                continue
            }
            if month == nil, let match = BikramSambatMonth.allCases.first(where: { caseMatches($0, token: token) }) {
                month = match
            }
        }
        guard let month, numbers.count == 2 else { return nil }
        // Day before year: the four-digit number is the Bikram Sambat year.
        let year = numbers.first(where: { $0 >= 1000 }) ?? numbers[1]
        let day = numbers.first(where: { $0 != year }) ?? numbers[0]
        return BikramSambatDateEntity(bsDay: BSDay(year: year, month: month.rawValue, day: day))
    }

    /// Exact, case-insensitive equality against titles and synonyms — never
    /// containment. The synonym table's near-collisions ("Aso" for Ashar,
    /// "Asoj"/"Asojh" for Ashoj) are pairs substring matching resolves
    /// wrongly, because the lower month number wins a first-match scan.
    private static func caseMatches(_ month: BikramSambatMonth, token: String) -> Bool {
        month.candidateStrings.contains { $0.caseInsensitiveCompare(token) == .orderedSame }
    }
}

/// Resolves Bikram Sambat dates from text and identifiers, so Shortcuts can
/// hand the entity around and type one in.
nonisolated struct BikramSambatDateQuery: EntityStringQuery {
    typealias Entity = BikramSambatDateEntity

    func entities(matching string: String) async throws -> [Entity] {
        Entity.parsing(string).map { [$0] } ?? []
    }

    func entities(for identifiers: [String]) async throws -> [Entity] {
        identifiers.compactMap { Entity(idString: $0) }
    }

    func suggestedEntities() async throws -> [Entity] {
        Entity.today().map { [$0] } ?? []
    }
}

nonisolated extension BikramSambatDateEntity {
    /// Rebuilds the entity from its `id` ("year-month-day").
    init?(idString: String) {
        let parts = idString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(bsDay: BSDay(year: year, month: month, day: day))
    }
}
