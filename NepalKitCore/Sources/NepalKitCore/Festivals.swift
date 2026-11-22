// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel

/// A festival or national day on a Bikram Sambat date, as the national
/// Panchanga (or, failing that, the gazette) names it.
public struct Festival: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// A festival or observance.
        case festival
        /// A national day of Nepal.
        case nationalDay
        /// An international day Nepal observes, such as Labour Day.
        case internationalDay
    }

    /// Where the entry was read.
    public enum Source: Hashable, Sendable {
        case panchanga
        case gazette
    }

    /// The source's own wording, in Devanagari.
    public let nepali: String
    /// The name in English, for the transliterated month-name setting.
    public let english: String
    public let kind: Kind
    public let source: Source

    public init(nepali: String, english: String, kind: Kind = .festival, source: Source = .panchanga) {
        self.nepali = nepali
        self.english = english
        self.kind = kind
        self.source = source
    }

    /// The name in the reader's month-name style.
    public func name(style: MonthNameStyle) -> String {
        style == .nepali ? nepali : english
    }
}

/// Festivals and national days by Bikram Sambat date. SOURCES.md records which
/// entries are selected.
public struct FestivalCalendar: Sendable {
    /// Years with festival data. A missing year is a gap, not a year without
    /// festivals.
    public let years: Set<Int>
    let entries: [BikramSambatDate: [Festival]]

    public init(years: Set<Int>, entries: [BikramSambatDate: [Festival]]) {
        self.years = years
        self.entries = entries
    }

    /// The festivals on `day`, in the Panchanga's order.
    public func festivals(on day: BikramSambatDate) -> [Festival] {
        entries[day] ?? []
    }

    /// Every entry, for checks that sweep the table.
    public var allEntries: [(day: BikramSambatDate, festivals: [Festival])] {
        entries.map { ($0.key, $0.value) }
    }

    /// The bundled calendar: every year read so far.
    public static let panchanga = FestivalCalendar(years: [2083], entries: festivals2083)
}
