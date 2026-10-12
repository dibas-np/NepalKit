// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// A festival or national day on a Bikram Sambat date, as the national
/// Panchanga prints it (ADR-0016), or, for a gazetted day the Panchanga does
/// not print, as the gazette names it.
public struct Festival: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// A festival or observance.
        case festival
        /// A national day of Nepal.
        case nationalDay
        /// An international day Nepal observes, such as Labour Day.
        case internationalDay
    }

    /// Where the entry was read: the Panchanga (ADR-0016), or the gazette
    /// notice for a gazetted day the Panchanga does not print, so the table can
    /// be checked against either.
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

    /// The name in the reader's month-name setting: the Panchanga's own
    /// wording with Nepali names, English with transliterated ones.
    public func name(style: MonthNameStyle) -> String {
        style == .nepali ? nepali : english
    }
}

/// Festivals and national days by Bikram Sambat date, for the years whose
/// national Panchanga has been read (ADR-0016).
public struct FestivalCalendar: Sendable {
    /// Years with festival data. A year outside this set has none yet, which
    /// is a gap, not a year without festivals.
    public let years: Set<Int>
    let entries: [BSDay: [Festival]]

    public init(years: Set<Int>, entries: [BSDay: [Festival]]) {
        self.years = years
        self.entries = entries
    }

    /// The festivals on `day`, in the Panchanga's order; empty when there are
    /// none or the year has no data.
    public func festivals(on day: BSDay) -> [Festival] {
        entries[day] ?? []
    }

    /// Every entry, for checks that sweep the table.
    public var allEntries: [(day: BSDay, festivals: [Festival])] {
        entries.map { ($0.key, $0.value) }
    }

    /// The bundled calendar: every year read so far.
    public static let panchanga = FestivalCalendar(years: [2083], entries: festivals2083)
}
