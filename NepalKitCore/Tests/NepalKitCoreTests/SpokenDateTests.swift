// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore

/// Covers the *transformation* — that the spoken form uses pronounceable digits
/// while keeping the user's month-name language, and that it agrees with the
/// visual form when there is no reason to differ.
///
/// It does not assert what VoiceOver says. Spoken output is a platform
/// rendering property; asserting it here would test nothing. The platform side
/// is checked by walking the real accessibility tree of the running app.
struct SpokenDateTests {
    private let ashoj11 = BSDay(year: 2083, month: 6, day: 11)
    private let adSeptember27 = GADay(year: 2026, month: 9, day: 27)

    @Test func spokenBSUsesLatinDigitsWithTransliteratedMonthName() {
        // 11 Ashoj 2083 — the visual form under Devanagari digits is
        // "११ असोज २०८३", whose digits are the part a voice may not read.
        #expect(SpokenDate.bs(ashoj11, monthNames: .transliterated) == "11 Ashoj 2083")
    }

    @Test func spokenBSKeepsTheUsersMonthNameLanguage() {
        // The month name is the semantically important half and a matching voice
        // reads it; overriding it would discard the user's own setting.
        #expect(SpokenDate.bs(ashoj11, monthNames: .nepali) == "11 असोज 2083")
    }

    @Test func spokenBSAgreesWithTheVisualFormWhenDigitsAreLatin() {
        // No cause to differ, so no override is applied. Announcing something
        // different from the screen would be its own defect.
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)

        #expect(SpokenDate.bs(ashoj11, monthNames: .transliterated) == formatBS(ashoj11, settings: settings))
    }

    @Test func spokenBSDropsDevanagariDigits() {
        // The point of the whole file: the digits must not survive into speech.
        let spoken = SpokenDate.bs(ashoj11, monthNames: .nepali)

        #expect(!spoken.contains("११"))
        #expect(!spoken.contains("२०८३"))
        #expect(spoken.contains("11") && spoken.contains("2083"))
    }

    @Test func spokenADUsesLatinDigitsAndAnEnglishMonthName() {
        #expect(SpokenDate.ad(adSeptember27) == "27 September 2026")
    }

    @Test func spokenNumbersAreLatinWhateverTheSetting() {
        #expect(SpokenDate.number(27) == "27")
    }

    @Test func gregorianAnnouncementFoldsInTheWeekdayWhenThereIsOne() {
        let date = GADay(year: 2026, month: 9, day: 27)

        #expect(SpokenDate.gregorianAnnouncement(date: date, weekday: "Sunday") == "27 September 2026, Sunday")
        #expect(SpokenDate.gregorianAnnouncement(date: date, weekday: nil) == "27 September 2026")
    }
}
