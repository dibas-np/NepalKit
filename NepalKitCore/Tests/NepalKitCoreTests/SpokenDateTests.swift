// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore

struct SpokenDateTests {
    private let ashoj11 = BikramSambatDate(year: 2083, month: 6, day: 11)
    private let adSeptember27 = GregorianDate(year: 2026, month: 9, day: 27)

    @Test func spokenBSUsesLatinDigitsWithTransliteratedMonthName() {
        #expect(SpokenDate.bikramSambat(ashoj11, monthNames: .transliterated) == "11 Ashoj 2083")
    }

    @Test func spokenBSKeepsTheUsersMonthNameLanguage() {
        #expect(SpokenDate.bikramSambat(ashoj11, monthNames: .nepali) == "11 असोज 2083")
    }

    @Test func spokenADUsesLatinDigitsAndAnEnglishMonthName() {
        #expect(SpokenDate.gregorian(adSeptember27) == "27 September 2026")
    }

    @Test func spokenNumbersAreLatinWhateverTheSetting() {
        #expect(SpokenDate.number(27) == "27")
    }
}
