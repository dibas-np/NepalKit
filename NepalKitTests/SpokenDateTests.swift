// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import Testing
@testable import NepalKit

/// Covers the app-side *composition* — the sentence a blind user actually meets
/// from the menu-bar extra: that it names the app so it is identifiable out of
/// context, and that it explains the range boundary rather than saying nothing.
///
/// The copy-free *transformation* those sentences are built from — pronounceable
/// digits, the user's month-name language, agreement with the visual form when
/// there is no reason to differ — is pure logic and now lives in `NepalKitCore`,
/// covered by `NepalKitCoreTests.SpokenDateTests`.
///
/// Neither suite asserts what VoiceOver says. Spoken output is a platform
/// rendering property; asserting it here would test nothing. The platform side
/// is checked by walking the real accessibility tree of the running app.
struct SpokenDateTests {
    private let ashoj11 = BSDay(year: 2083, month: 6, day: 11)
    private let adSeptember27 = GADay(year: 2026, month: 9, day: 27)

    @Test func menuBarNamesTheAppSoItIsIdentifiableOutOfContext() {
        // The only surface a blind user meets before opening anything. A bare
        // date says nothing about which app it belongs to.
        let spoken = SpokenDate.menuBar(today: ashoj11, monthNames: .transliterated, dataset: .v2)

        #expect(spoken == "NepalKit, 11 Ashoj 2083")
        #expect(spoken.hasPrefix("NepalKit"))
    }

    @Test func menuBarExplainsTheBoundaryRatherThanSayingNothing() {
        // A bare "n/a" spoken alone reads as a broken menu-bar item. The end
        // date is the dataset's own Gregorian end — 12 April 2028 — derived,
        // not spelled in a string somewhere.
        let spoken = SpokenDate.menuBar(today: nil, monthNames: .transliterated, dataset: .v2)

        #expect(spoken.hasPrefix("NepalKit"))
        #expect(spoken != "NepalKit, n/a")
        #expect(spoken.contains("calendar data ends 12 April 2028"))
    }
}

/// The two places where a spoken form is wired into a real surface. Both are
/// checked against the same conversion the screen shows, so the pair is what
/// actually matters: the announcement must not describe a different day than
/// the pixels.
@MainActor
struct SpokenSurfaceTests {
    @Test func menuBarAnnouncementUsesPronounceableDigitsAndNamesTheApp() {
        let model = MenuBarModel(now: Date(timeIntervalSince1970: 1_792_272_000), schedulesMidnightFire: false)

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
        let model = MenuBarModel(now: Date(timeIntervalSince1970: 1_848_096_000), schedulesMidnightFire: false)

        let spoken = model.spokenTitle(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))

        #expect(spoken.contains("NepalKit"))
        #expect(spoken.contains("calendar data ends"))
    }

    @Test func converterSpokenResultMatchesTheShownDate() throws {
        let model = ConverterModel()
        model.setDirection(.bsToAD)
        model.bsYear = 2083
        model.bsMonth = 6
        model.bsDay = 11

        let settings = DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        let shown = try #require(model.convertedText(settings: settings))
        let spoken = try #require(model.spokenResult(settings: settings))

        // Same day, different channel: the digits are Latin in speech and
        // Devanagari on screen.
        #expect(!spoken.contains("२"))
        #expect(shown.contains("२"))
        // The weekday survives, since a date without one is less useful aloud.
        #expect(spoken.contains(","))
    }

    @Test func converterSpokenResultKeepsTheUsersMonthLanguage() throws {
        let model = ConverterModel()
        // Via `setDirection`; the AD pickers below overwrite what it carries.
        model.setDirection(.adToBS)
        model.adYear = 2026
        model.adMonth = 9
        model.adDay = 27

        #expect(try #require(model.spokenResult(settings: DisplaySettings(digits: .latin, monthNames: .nepali))).contains("असोज"))
        #expect(try #require(model.spokenResult(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))).contains("Ashoj"))
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
        // The announcement must not depend on the voice reading Devanagari, nor
        // on how it renders an en dash: it is said only, so there is no shown
        // punctuation left to protect and a plain hyphen is unambiguous.
        #expect(Strings.digitsDevanagariSpoken == "Devanagari 0-9")
        #expect(!Strings.digitsDevanagariSpoken.contains("०"))
    }
    @Test func noSpokenStringCarriesTypographicPunctuationOrSymbols() throws {
        // The en dash in "1975–2084 BS" is right on screen and unpredictable
        // aloud - some voices say "1975 dash 2084", some pause, some drop it. The
        // same goes for separators and symbols. Anything typographic in the
        // spoken channel is a defect even when the string reads correctly, which
        // is why this sweeps the whole set rather than the one known case.
        //
        // Exercised over every month, both month languages and the boundary
        // states, because a glyph can hide in a branch that a single
        // representative sample never reaches. Only one digit script needs
        // sweeping: the spoken channel is always Latin by construction, so
        // there is no Devanagari-spoken branch that could hide a glyph.
        let forbidden: Set<Character> = [
            "\u{2013}", "\u{2014}",  // en dash, em dash
            "\u{00B7}",              // middle dot, used between the two dates
            "\u{2192}", "\u{2190}", // arrows, used in the direction segments
            "\u{2699}", "\u{24D8}", // gear, circled i
            "\u{00B0}", "\u{2032}", "\u{2033}", // degree, prime, double prime
            "\u{2026}",              // ellipsis, in "Settings\u{2026}"
        ]
        var offenders: [String] = []

        for style in [MonthNameStyle.nepali, .transliterated] {
            for month in 1 ... 12 {
                let name = monthName(month: month, style: style)
                if name.contains(where: { forbidden.contains($0) }) {
                    offenders.append("month name \(name)")
                }
            }
        }

        for month in 1 ... 12 {
            let gregorian = gregorianMonthName(month)
            if gregorian.contains(where: { forbidden.contains($0) }) {
                offenders.append("gregorian month \(gregorian)")
            }
        }

        let date = GADay(year: 2026, month: 9, day: 27)
        for style in [MonthNameStyle.nepali, .transliterated] {
            let spoken = SpokenDate.gregorianAnnouncement(date: date, weekday: weekdayName(for: weekday(of: date) ?? 1, style: style))
            if spoken.contains(where: { forbidden.contains($0) }) {
                offenders.append("gregorian announcement \(spoken)")
            }
        }
        let numeric = SpokenDate.number(2083)
        if numeric != numeric.trimmingCharacters(in: .whitespaces) {
            offenders.append("number carries padding: \(numeric)")
        }

        // The boundary strings, including the menu-bar variants, which are the
        // ones a user past the range hears instead of a date.
        let bs = BSDay(year: 2083, month: 6, day: 11)
        for style in [MonthNameStyle.nepali, .transliterated] {
            for spoken in [
                SpokenDate.bs(bs, monthNames: style),
                SpokenDate.menuBar(today: bs, monthNames: style, dataset: .v2),
                SpokenDate.menuBar(today: nil, monthNames: style, dataset: .v2),
            ] {
                if spoken.contains(where: { forbidden.contains($0) }) {
                    offenders.append("bs spoken form \(spoken)")
                }
            }
        }

        offenders += try Self.stringsConstantsReachingTheSpokenChannel(forbidden: forbidden)

        #expect(offenders.isEmpty, "typographic characters in the spoken channel: \(offenders)")
    }

    /// The `Strings` constants that reach the spoken channel carrying
    /// typographic punctuation, derived from the source rather than listed by
    /// hand.
    ///
    /// An enumerated list fixes the constants reviewed today and says nothing
    /// about the one added tomorrow, which is the failure the sweep exists to
    /// prevent — so the inputs are parsed and every constant falls into exactly
    /// one of three classes:
    ///
    /// 1. its name ends in `Spoken`, so it is said: it must be clean.
    /// 2. its value is typographic and it is shown: it must have a
    ///    `<name>Spoken` counterpart, because a `Text` in a `Picker` item or a
    ///    `Button` title becomes that element's `AXName` on its own, whether or
    ///    not anyone writes an `.accessibilityLabel` for it.
    /// 3. its value is typographic and it never reaches a screen reader: named
    ///    in `shownThatNeverAnnounces`, with the code that proves it.
    ///
    /// A constant fitting none of the three is an offender, so a shown label
    /// written with an en dash and no spoken form is red from the day it lands.
    private static func stringsConstantsReachingTheSpokenChannel(
        forbidden: Set<Character>
    ) throws -> [String] {
        // Proven not announced: the popover's weekday line is a visible `Text`
        // inside an `HStack` that carries an explicit `.accessibilityLabel` of
        // `SpokenDate.gregorianAnnouncement`, so the middle dot is replaced
        // before it reaches the accessibility tree (PopoverView.swift). The
        // converter's shown line is the only other use, and it is the `.shown`
        // half of a tuple whose `.spoken` half is built separately.
        let shownThatNeverAnnounces: Set<String> = ["weekdaySeparator"]
        // A `static let` this cannot read a value out of is a hole in the sweep,
        // so it is named rather than skipped — which is what makes the constant
        // added tomorrow fail instead of going unchecked. `licenseScopeNote` was
        // one: multi-line prose shown verbatim on the About surface, carrying no
        // typographic punctuation, so it could only be checked by reading it. It
        // went with that surface. The set is kept rather than deleted because the
        // parser's blind spot is real — the next multi-line string added will hit
        // it — and an empty set here is the honest way to say "none today" while
        // leaving the exemption mechanism in place.
        let proseTheParserCannotRead: Set<String> = []

        var offenders: [String] = []
        let constants = try declaredStringConstants()
        for (name, value) in constants.sorted(by: { $0.key < $1.key })
        where value.contains(where: { forbidden.contains($0) }) {
            if name.hasSuffix("Spoken") {
                offenders.append("\(name) is spoken and carries typographic punctuation")
            } else if !shownThatNeverAnnounces.contains(name),
                      !constants.keys.contains("\(name)Spoken") {
                // Shown, typographic, and with neither an exemption nor a clean
                // spoken counterpart: announced exactly as it reads.
                offenders.append("\(name) is announced as shown and has no spoken form")
            }
            // Otherwise the constant is shown with a clean `<name>Spoken`
            // counterpart — the split this exists to enforce, and itself swept by
            // the first branch — or it is named in `shownThatNeverAnnounces`.
        }
        for name in try unparsedConstantNames() where !proseTheParserCannotRead.contains(name) {
            offenders.append("\(name) is a `static let` this sweep cannot read; classify it")
        }
        return offenders
    }

    /// The `Strings` constants whose value is a single-line string literal, by
    /// name.
    ///
    /// Read from source because Swift offers no way to enumerate them: `Strings`
    /// has no cases and no instance storage, and `Mirror` reflects neither static
    /// properties nor type-level metadata — `Mirror(reflecting: Strings.self)`
    /// returns no children at all. `SymbolTests.declaredConstants()` parses
    /// `Symbols.swift` the same way, for the same reason.
    private static func declaredStringConstants() throws -> [String: String] {
        var found: [String: String] = [:]
        for line in try sourceLines() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let name = constantName(in: trimmed), let equals = trimmed.range(of: " = ") {
                if let literal = singleLineLiteral(String(trimmed[equals.upperBound...])) {
                    found[name] = literal
                }
            }
        }
        return found
    }

    /// The value of the string literal at the head of `tail`, or nil when there
    /// is none on this line.
    ///
    /// A `"""` opener is a multi-line literal, whose value is not on its
    /// declaration line. Reading it as an ordinary literal would yield a value of
    /// a single quote, which passes every check while checking nothing — so it is
    /// left unparsed, and `unparsedConstantNames()` names it instead.
    private static func singleLineLiteral(_ tail: String) -> String? {
        guard let opening = tail.firstIndex(of: "\""),
              !String(tail[opening...]).hasPrefix("\"\"\""),
              let closing = closingQuote(in: tail, from: tail.index(after: opening))
        else { return nil }
        return String(tail[opening ..< closing])
    }

    /// The `static let` names this sweep has no value for, so that a constant
    /// added in a shape the parser cannot read fails the test instead of
    /// quietly going unchecked.
    private static func unparsedConstantNames() throws -> [String] {
        let parsed = try declaredStringConstants()
        return try sourceLines()
            .compactMap { constantName(in: $0.trimmingCharacters(in: .whitespaces)) }
            .filter { parsed[$0] == nil }
    }

    private static func sourceLines() throws -> [String] {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent("NepalKit/Strings.swift"),
            encoding: .utf8
        ).split(separator: "\n").map(String.init)
    }

    private static func constantName(in line: String) -> String? {
        guard line.hasPrefix("static let ") else { return nil }
        let rest = line.dropFirst("static let ".count)
        let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        return name.isEmpty ? nil : String(name)
    }

    /// The index of the quote closing the literal opening at `opening`, skipping
    /// `\"` so a later quote inside an escape cannot be mistaken for the end.
    private static func closingQuote(in line: String, from opening: String.Index) -> String.Index? {
        var index = opening
        while index < line.endIndex {
            switch line[index] {
            case "\\":
                index = line.index(index, offsetBy: 2, limitedBy: line.endIndex) ?? line.endIndex
            case "\"":
                return index
            default:
                index = line.index(after: index)
            }
        }
        return nil
    }

    /// The repository root, found by searching upward for the project file.
    ///
    /// The same walk `SymbolTests` documents: this test compiles through the
    /// harness at `scripts/apptests/Tests/NepalKitTests/`, so `#filePath` is the
    /// symlinked path at run time and hop-counting lands in `Tests/` instead of
    /// the root. Searching upward from either form cannot depend on which one is
    /// in effect.
    private static var repositoryRoot: URL {
        for base in [URL(fileURLWithPath: #filePath), URL(fileURLWithPath: #filePath).standardizedFileURL] {
            var dir = base.deletingLastPathComponent()
            for _ in 0 ..< 10 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("NepalKit.xcodeproj").path) {
                    return dir
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    @Test func spokenSupportedRangeAvoidsTheEnDash() {
        // Pins the one case the sweep above is really about, named explicitly so
        // a regression points at the cause rather than the sweep.
        let spoken = Strings.supportedRangeSpoken(1975 ... 2084)
        #expect(!spoken.contains("\u{2013}"), "en dash survives in the spoken range: \(spoken)")
        #expect(spoken == "1975 to 2084 BS")
    }
}
