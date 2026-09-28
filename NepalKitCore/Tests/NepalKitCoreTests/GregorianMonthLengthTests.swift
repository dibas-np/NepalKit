// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore

/// `daysInGregorianMonth` backs the converter's Gregorian day-picker bounds.
/// Facts read off any published Gregorian calendar.
struct GregorianMonthLengthTests {
    @Test func lengthsMatchThePublishedCalendar() {
        // 2026: September 30, December 31; February 28 (2023) and 29 (2024, leap).
        #expect(daysInGregorianMonth(year: 2026, month: 9) == 30)
        #expect(daysInGregorianMonth(year: 2026, month: 12) == 31)
        #expect(daysInGregorianMonth(year: 2023, month: 2) == 28)
        #expect(daysInGregorianMonth(year: 2024, month: 2) == 29)
    }

    @Test func impossibleMonthsAreRejected() {
        // Calendar would silently normalize month 0 into December of the
        // previous year, so the boundary guard is what keeps this nil.
        #expect(daysInGregorianMonth(year: 2026, month: 0) == nil)
        #expect(daysInGregorianMonth(year: 2026, month: 13) == nil)
    }
}
