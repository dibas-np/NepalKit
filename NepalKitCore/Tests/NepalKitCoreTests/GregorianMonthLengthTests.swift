// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore

struct GregorianMonthLengthTests {
    @Test func lengthsMatchThePublishedCalendar() {
        // 2026: September 30, December 31; February 28 (2023) and 29 (2024, leap).
        #expect(GregorianDate.daysInMonth(year: 2026, month: 9) == 30)
        #expect(GregorianDate.daysInMonth(year: 2026, month: 12) == 31)
        #expect(GregorianDate.daysInMonth(year: 2023, month: 2) == 28)
        #expect(GregorianDate.daysInMonth(year: 2024, month: 2) == 29)
    }

    @Test func impossibleMonthsAreRejected() {
        #expect(GregorianDate.daysInMonth(year: 2026, month: 0) == nil)
        #expect(GregorianDate.daysInMonth(year: 2026, month: 13) == nil)
    }
}
