// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// A Bikram Sambat date as Shortcuts sees it. The title uses the user's display
/// settings; the spoken dialog stays in `SpokenDate` form.
nonisolated struct BikramSambatDateEntity: AppEntity, Hashable, Sendable {
    private let date: BikramSambatDate
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
        lhs.date == rhs.date
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
    }

    var id: String { "\(year)-\(month.rawValue)-\(day)" }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bikram Sambat date")

    static let defaultQuery = BikramSambatDateQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(bsDay.formatted(SettingsStore().settings))")
    }

    var bsDay: BikramSambatDate { date }

    /// Validates the calendar day and supplies its weekday for every query path.
    init?(bsDay: BikramSambatDate, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) {
        guard let month = BikramSambatMonth(rawValue: bsDay.month),
              let gregorian = GregorianDate(bsDay, in: AppData.dataset) else { return nil }
        self.date = bsDay
        self.calendarMonth = month
        self.weekdayValue = IntentAnswers.weekdayNameString(gregorian.weekday, monthNames: monthNames)
    }

    /// Today's date in the user's time reference (ADR-0017), or nil past the supported range.
    static func today() -> BikramSambatDateEntity? {
        let timeZone = SettingsStore().timeReference.timeZone
        guard let bs = BikramSambatDate.today(now: Date(), timeZone: timeZone, in: AppData.dataset) else { return nil }
        return BikramSambatDateEntity(bsDay: bs)
    }

    /// Best-effort parse of text like "15 Ashar 2082". Months match a title or
    /// synonym exactly; only Latin digits are parsed.
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
        return BikramSambatDateEntity(bsDay: BikramSambatDate(year: year, month: month.rawValue, day: day))
    }

    /// Exact matching, never containment: synonyms like "Aso" (Ashar) and "Asoj"
    /// (Ashoj) would otherwise resolve to the wrong month.
    private static func caseMatches(_ month: BikramSambatMonth, token: String) -> Bool {
        month.candidateStrings.contains { $0.caseInsensitiveCompare(token) == .orderedSame }
    }
}

/// Resolves Bikram Sambat dates from typed text and identifiers.
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
    init?(idString: String) {
        let parts = idString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(bsDay: BikramSambatDate(year: year, month: month, day: day))
    }
}
