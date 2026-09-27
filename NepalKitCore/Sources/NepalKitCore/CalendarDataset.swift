/// A versioned Bikram Sambat month-length table with its conversion anchor.
///
/// Month lengths are declared per year by the official Nepali Patro; there is
/// no closed-form algorithm, so conversion is table-driven. The sample table
/// below covers the skeleton range only — ticket 02 replaces it with the full
/// verified transcription.
public struct CalendarDataset: Sendable {
    /// Dataset version, e.g. "0.1.0-skeleton" for the walking skeleton.
    public let version: String

    /// BS year to its twelve month lengths (Baisakh through Chaitra).
    public let years: [Int: [Int]]

    /// The anchor tying the table to the Gregorian calendar:
    /// 1 Baisakh 2082 BS is 14 April 2025 AD.
    public let anchorBS: BSDay
    public let anchorAD: GADay

    public init(version: String, years: [Int: [Int]], anchorBS: BSDay, anchorAD: GADay) {
        self.version = version
        self.years = years
        self.anchorBS = anchorBS
        self.anchorAD = anchorAD
    }

    public var supportedRange: ClosedRange<Int> {
        guard let lo = years.keys.min(), let hi = years.keys.max() else {
            return 0 ... -1
        }
        return lo ... hi
    }

    public func monthLengths(for bsYear: Int) -> [Int]? {
        years[bsYear]
    }

    /// Skeleton sample: verified rows for 2082–2083 BS.
    public static let sample = CalendarDataset(
        version: "0.1.0-skeleton",
        years: [
            2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
            2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
        ],
        anchorBS: BSDay(year: 2082, month: 1, day: 1),
        anchorAD: GADay(year: 2025, month: 4, day: 14)
    )
}

/// A date in the Bikram Sambat calendar.
public struct BSDay: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

/// A date in the Gregorian calendar.
public struct GADay: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}
