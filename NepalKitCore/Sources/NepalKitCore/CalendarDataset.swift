// SPDX-License-Identifier: GPL-3.0-or-later AND MIT
// Copyright (C) 2026 Dibas Sigdel
// Copyright (c) 2023 Ask Buddie (historical base table)
/// A versioned Bikram Sambat month-length table with its conversion anchor.
///
/// The historical base is askbuddie/bikram-sambat at the commit pinned in
/// SOURCES.md, under MIT, copyright (c) 2023 Ask Buddie. Its complete notice
/// is bundled in Resources/AskBuddie-LICENSE.txt.
///
/// NepalKit retains 14 local month-length corrections across 1989, 1993,
/// 2004, 2082 and 2083. The 2084 row is the maintainer's own provisional
/// development/testing projection, not official calendar attestation.
/// SOURCES.md records every exception and its evidence limits; ADR-0014
/// governs the current base and update policy.
///
/// Supported range: 1975-2084 Bikram Sambat, 1918-04-13 through 2028-04-12
/// Gregorian. Dataset 2.0.1 keeps the existing anchor, values and range.
public struct CalendarDataset: Sendable {
    /// Dataset version, e.g. "2.0.0" for the table narrowed to 1975-2084 BS.
    public let version: String

    /// BS year to its twelve month lengths (Baisakh through Chaitra).
    public let years: [Int: [Int]]

    /// The anchor tying the table to the Gregorian calendar:
    /// 1 Baisakh 2082 in Bikram Sambat is 14 April 2025 in the Gregorian calendar.
    /// (`BS`/`AD` survive only in type and function names, where the spec standardizes on them.)
    public let anchorBS: BSDay
    public let anchorAD: GADay

    /// Explicitly declared supported range (ADR-0002), not derived.
    public let supportedRange: ClosedRange<Int>

    /// Absolute day index of each supported year's first day (lookup cache).
    let yearStartIndices: [Int: Int]

    public init(version: String, years: [Int: [Int]], anchorBS: BSDay, anchorAD: GADay, supportedRange: ClosedRange<Int>) {
        self.version = version
        self.years = years
        self.anchorBS = anchorBS
        self.anchorAD = anchorAD
        self.supportedRange = supportedRange
        var starts: [Int: Int] = [:]
        var cursor = 0
        for year in supportedRange {
            starts[year] = cursor
            // A declared range year with a missing or non-twelve-month row would
            // either silently shift every later year's index or crash at the
            // month lookup, corrupting conversions either way. A broken dataset
            // must fail loudly at construction, not convert wrong.
            guard let lengths = years[year], lengths.count == 12 else {
                preconditionFailure("CalendarDataset \(version): supported-range year \(year) does not have a twelve-month row")
            }
            cursor += lengths.reduce(0, +)
        }
        self.yearStartIndices = starts
    }

    public func monthLengths(for bsYear: Int) -> [Int]? {
        years[bsYear]
    }

    /// The first day the table can express, as a Gregorian civil day: the
    /// Gregorian start of `supportedRange`. Nil only if the table is broken.
    ///
    /// Derived, never stored, for the same reason `gregorianEnd` is: the
    /// Watch's boundary classification and support context read the exact
    /// bounds, so a table change moves them without a Gregorian literal to
    /// hunt down.
    public var gregorianStart: GADay? {
        bsToAD(BSDay(year: supportedRange.lowerBound, month: 1, day: 1), in: self)
    }

    /// The last day the table can express, as a Gregorian civil day: the
    /// Gregorian end of `supportedRange`. Nil only if the table is broken.
    ///
    /// Derived, never stored: the About surface and the spoken boundary
    /// sentence both read this, so a table change moves them without a
    /// Gregorian literal to hunt down (ADR-0010).
    public var gregorianEnd: GADay? {
        guard let months = monthLengths(for: supportedRange.upperBound),
              months.count == 12
        else { return nil }
        return bsToAD(BSDay(year: supportedRange.upperBound, month: 12, day: months[11]), in: self)
    }

    // MIT base with explicit NepalKit corrections and a local 2084 projection.
    // See SOURCES.md for the pinned reference, exceptions and evidence limits.
    public static let v2 = CalendarDataset(
        version: "2.0.1",
        years: [
            1975: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            1976: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            1977: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            1978: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1979: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            1980: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            1981: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            1982: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1983: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            1984: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            1985: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            1986: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1987: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            1988: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            1989: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            1990: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1991: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            1992: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            1993: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            1994: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1995: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            1996: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            1997: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1998: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            1999: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2000: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2001: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2002: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2003: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2004: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2005: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2006: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2007: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2008: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
            2009: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2010: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2011: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2012: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            2013: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2014: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2015: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2016: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            2017: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2018: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2019: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2020: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            2021: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2022: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            2023: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2024: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            2025: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2026: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2027: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2028: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2029: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
            2030: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2031: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2032: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2033: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2034: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2035: [30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
            2036: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2037: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2038: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2039: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            2040: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2041: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2042: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2043: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            2044: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2045: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2046: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2047: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            2048: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2049: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            2050: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2051: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            2052: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2053: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            2054: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2055: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2056: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
            2057: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2058: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2059: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2060: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2061: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2062: [31, 31, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
            2063: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2064: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2065: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2066: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
            2067: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2068: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2069: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2070: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
            2071: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2072: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            2073: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            2074: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
            2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2080: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
            2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
            2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2084: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
        ],
        anchorBS: BSDay(year: 2082, month: 1, day: 1),
        anchorAD: GADay(year: 2025, month: 4, day: 14),
        supportedRange: 1975 ... 2084
    )
}
