// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
/// A versioned Bikram Sambat month-length table with its conversion anchor.
///
/// Month lengths are declared per year by the official Nepali Patro; there is
/// no closed-form algorithm, so conversion is table-driven.
///
/// **Provenance is documented in `SOURCES.md` at the repository root**, with
/// every source pinned to a commit, its licence and role recorded, and each
/// arbitrated month listed. That document also states plainly what this table is
/// not: it is not independently licensed. Read it before describing this data
/// as verified or permissively sourced.
///
/// Provenance: month rows reproduce the officially approved
/// annual Nepali Patro. Three community tables were cross-checked
/// month-by-month (107/116 identical); all 9 disputes were arbitrated against
/// published Patro reproductions (KMC government grids, Hamro Patro, Nepali
/// Patro, mypatro, ashesh, rat32, khudra), with tithi-continuity, weekday, and
/// month-handoff checks. New Year boundaries were checked against an independent
/// anchor list over 1970-2090 — a wider window than this type ships, so that a
/// table change could be detected from either end; two single-day typos in that
/// list were corrected (1975, 2089). Range capped at 2084: the current officially
/// published year; 2085+ excluded, no extrapolated years (ADR-0001).
///
/// Dataset 2.0.0 narrows the lower bound to 1975. The five years 1970-1974
/// were the only ones the cross-check did not corroborate against a second
/// table, and the cross-check they were missing from is what makes the rest of
/// the range defensible. This is a breaking change to the conversion contract
/// and a data-contract major bump, not a fix (ADR-0010). The Gregorian lower
/// bound is a consequence of this range, not a setting of its own: 1 Baisakh 1975
/// is 13 April 1918, so the convertible span begins there.
///
/// **Transcribe from a current checkout, not a pre-2025-03-14 one.** The base
/// table `medic/bikram-sambat` shipped wrong Falgun and Chaitra lengths for BS
/// 2081, corrected in its PR #27 (merged 14 March 2025). The shipped rows here
/// are the corrected ones and match upstream exactly. The correction is
/// dangerous to miss because the *year total is 366 either way* — 29+31 and
/// 30+30 redistribute the same days — so a stale transcription produces the
/// right 1 Baisakh 2082 and passes every year-level check while shifting all of
/// Chaitra 2081 by a day and rejecting a real 31 Chaitra 2081. Re-verify those
/// two rows after any re-transcription. See the coverage note in ADR-0010.
///
/// **2085 is absent on purpose.** The base table carries rows past 2084; they are
/// not shipped because 2085 is not officially published, and "the source has it"
/// is not a reason to widen the conversion contract (ADR-0001).
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

    // Verified table: 1975-2084 BS (1918-04-13 through 2028-04-12 Gregorian).
    // The table below is NOT covered by the SPDX identifier at the top of
    // this file. The code is GPL-3.0-or-later; the data is derived work whose
    // licence chain does not terminate in a clear grant, and no licence this
    // project applies can supply one. See SOURCES.md.
    // SPDX-License-Identifier: LicenseRef-see-SOURCES.md
    public static let v2 = CalendarDataset(
        version: "2.0.0",
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
            2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
        ],
        anchorBS: BSDay(year: 2082, month: 1, day: 1),
        anchorAD: GADay(year: 2025, month: 4, day: 14),
        supportedRange: 1975 ... 2084
    )
}
