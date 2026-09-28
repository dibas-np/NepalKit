// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import Testing
@testable import NepalKit

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

    @Test func menuBarNamesTheAppSoItIsIdentifiableOutOfContext() {
        // The only surface a blind user meets before opening anything. A bare
        // date says nothing about which app it belongs to.
        let spoken = SpokenDate.menuBar(today: ashoj11, monthNames: .transliterated)

        #expect(spoken == "NepalKit, 11 Ashoj 2083")
        #expect(spoken.hasPrefix("NepalKit"))
    }

    @Test func menuBarExplainsTheBoundaryRatherThanSayingNothing() {
        // A bare "n/a" spoken alone reads as a broken menu-bar item.
        let spoken = SpokenDate.menuBar(today: nil, monthNames: .transliterated)

        #expect(spoken.hasPrefix("NepalKit"))
        #expect(spoken != "NepalKit, n/a")
        #expect(spoken.contains("calendar data ends"))
    }
}

/// The two places where a spoken form is wired into a real surface. Both are
/// checked against the same conversion the screen shows, so the pair is what
/// actually matters: the announcement must not describe a different day than
/// the pixels.
@MainActor
struct SpokenSurfaceTests {
    @Test func menuBarAnnouncementUsesPronounceableDigitsAndNamesTheApp() {
        let model = MenuBarModel(now: Date(timeIntervalSince1970: 1_792_272_000))

        let spoken = model.spokenTitle(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated))
        let shown = model.title(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated))

        #expect(spoken.hasPrefix("NepalKit"))
        // The screen keeps Devanagari; only the announcement is Latin.
        #expect(shown != spoken)
        #expect(!spoken.contains("२"))
        #expect(!spoken.contains("१"))
    }

    @Test func menuBarAnnouncementPastTheRangeExplainsItself() {
        // 2028-04-13 is the first day outside the shipped dataset.
        let model = MenuBarModel(now: Date(timeIntervalSince1970: 1_848_096_000))

        let spoken = model.spokenTitle(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))

        #expect(spoken.contains("NepalKit"))
        #expect(spoken.contains("calendar data ends"))
    }

    @Test func converterSpokenResultMatchesTheShownDate() throws {
        let model = ConverterModel()
        model.direction = .bsToAD
        model.bsYear = 2083
        model.bsMonth = 6
        model.bsDay = 11

        let settings = DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        let shown = try #require(model.convertedText(settings: settings))
        let spoken = try #require(model.spokenResult(monthNames: .transliterated))

        // Same day, different channel: the digits are Latin in speech and
        // Devanagari on screen.
        #expect(!spoken.contains("२"))
        #expect(shown.contains("२"))
        // The weekday survives, since a date without one is less useful aloud.
        #expect(spoken.contains(","))
    }

    @Test func converterSpokenResultKeepsTheUsersMonthLanguage() throws {
        let model = ConverterModel()
        model.direction = .adToBS
        model.adYear = 2026
        model.adMonth = 9
        model.adDay = 27

        #expect(try #require(model.spokenResult(monthNames: .nepali)).contains("असोज"))
        #expect(try #require(model.spokenResult(monthNames: .transliterated)).contains("Ashoj"))
    }

    @Test func gregorianAnnouncementFoldsInTheWeekdayWhenThereIsOne() {
        let date = GADay(year: 2026, month: 9, day: 27)

        #expect(SpokenDate.gregorianAnnouncement(date: date, weekday: "Sunday") == "27 September 2026, Sunday")
        #expect(SpokenDate.gregorianAnnouncement(date: date, weekday: nil) == "27 September 2026")
    }

    @Test func supportedRangeIsSpokenWithoutTheEnDash() {
        // On screen the en dash is right. Read aloud it is unpredictable — some
        // voices say "dash", some pause — so the announcement spells "to".
        let range = 1975...2084

        #expect(Strings.supportedRange(range) == "1975–2084 BS")
        #expect(Strings.supportedRangeSpoken(range) == "1975 to 2084 BS")
    }
}

/// Found by walking the live accessibility tree of the running app, which
/// exposed the Devanagari digit option's own label — ०–९ — straight to the
/// accessibility API. Reading the source had not surfaced it.
struct SpokenOptionLabelTests {
    @Test func devanagariOptionIsShownWithItsDigitsButSpokenWithLatinOnes() {
        // The screen must keep the characters the option actually selects.
        #expect(Strings.digitsDevanagari == "Devanagari ०–९")
        // The announcement must not depend on the voice reading Devanagari.
        #expect(Strings.digitsDevanagariSpoken == "Devanagari 0–9")
        #expect(!Strings.digitsDevanagariSpoken.contains("०"))
    }
}
