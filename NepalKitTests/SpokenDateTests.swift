// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import Testing
@testable import NepalKit

struct SpokenDateTests {
    private let ashoj11 = BikramSambatDate(year: 2083, month: 6, day: 11)
    private let adSeptember27 = GregorianDate(year: 2026, month: 9, day: 27)

    @Test func menuBarNamesTheAppSoItIsIdentifiableOutOfContext() {
        let spoken = SpokenDate.menuBar(today: ashoj11, monthNames: .transliterated, dataset: .v2)

        #expect(spoken == "NepalKit, 11 Ashoj 2083")
        #expect(spoken.hasPrefix("NepalKit"))
    }

    @Test func menuBarExplainsTheBoundaryRatherThanSayingNothing() {
        let spoken = SpokenDate.menuBar(today: nil, monthNames: .transliterated, dataset: .v2)

        #expect(spoken.hasPrefix("NepalKit"))
        #expect(spoken != "NepalKit, n/a")
        #expect(spoken.contains("calendar data ends 12 April 2028"))
    }
}

@MainActor
struct SpokenSurfaceTests {
    @Test func menuBarAnnouncementUsesPronounceableDigitsAndNamesTheApp() {
        let model = MenuBarModel(now: Date(timeIntervalSince1970: 1_792_272_000), schedulesMidnightFire: false)

        let spoken = model.spokenTitle(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated))
        let shown = model.title(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated))

        #expect(spoken.hasPrefix("NepalKit"))
        #expect(shown != spoken)
        #expect(!spoken.contains("२"))
        #expect(!spoken.contains("१"))
    }

    @Test func menuBarAnnouncementPastTheRangeExplainsItself() throws {
        let model = MenuBarModel(now: try TestDates.utc(2028, 7, 25, 0, 0), schedulesMidnightFire: false)

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

        #expect(!spoken.contains("२"))
        #expect(shown.contains("२"))
        #expect(spoken.contains(","))
    }

    @Test func converterSpokenResultKeepsTheUsersMonthLanguage() throws {
        let model = ConverterModel()
        model.setDirection(.adToBS)
        model.adYear = 2026
        model.adMonth = 9
        model.adDay = 27

        #expect(try #require(model.spokenResult(settings: DisplaySettings(digits: .latin, monthNames: .nepali))).contains("असोज"))
        #expect(try #require(model.spokenResult(settings: DisplaySettings(digits: .latin, monthNames: .transliterated))).contains("Ashoj"))
    }

    @Test func supportedRangeIsSpokenWithoutTheEnDash() {
        let range = 1975...2084

        #expect(Strings.supportedRange(range) == "1975–2084 BS")
        #expect(Strings.supportedRangeSpoken(range) == "1975 to 2084 BS")
    }
}

struct SpokenOptionLabelTests {
    @Test func devanagariOptionIsShownWithItsDigitsButSpokenWithLatinOnes() {
        #expect(Strings.digitsDevanagari == "Devanagari ०–९")
        #expect(Strings.digitsDevanagariSpoken == "Devanagari 0-9")
        #expect(!Strings.digitsDevanagariSpoken.contains("०"))
    }
    @Test func noSpokenStringCarriesTypographicPunctuationOrSymbols() throws {
        let forbidden: Set<Character> = [
            "–", "—", "·", "→", "←", "⚙", "ⓘ", "°", "′", "″", "…",
        ]
        var offenders: [String] = []

        for style in [MonthNameStyle.nepali, .transliterated] {
            for month in 1 ... 12 {
                let name = BikramSambatDate.monthName(month, style: style)
                if name.contains(where: { forbidden.contains($0) }) {
                    offenders.append("month name \(name)")
                }
            }
        }

        for month in 1 ... 12 {
            let gregorian = GregorianDate.monthName(month)
            if gregorian.contains(where: { forbidden.contains($0) }) {
                offenders.append("gregorian month \(gregorian)")
            }
        }

        let date = GregorianDate(year: 2026, month: 9, day: 27)
        for style in [MonthNameStyle.nepali, .transliterated] {
            let spoken = SpokenDate.gregorianAnnouncement(date: date, weekday: BikramSambatDate.weekdayName(date.weekday ?? 1, style: style))
            if spoken.contains(where: { forbidden.contains($0) }) {
                offenders.append("gregorian announcement \(spoken)")
            }
        }
        let numeric = SpokenDate.number(2083)
        if numeric != numeric.trimmingCharacters(in: .whitespaces) {
            offenders.append("number carries padding: \(numeric)")
        }

        let bs = BikramSambatDate(year: 2083, month: 6, day: 11)
        for style in [MonthNameStyle.nepali, .transliterated] {
            for spoken in [
                SpokenDate.bikramSambat(bs, monthNames: style),
                SpokenDate.menuBar(today: bs, monthNames: style, dataset: .v2),
                SpokenDate.menuBar(today: nil, monthNames: style, dataset: .v2),
            ] where spoken.contains(where: { forbidden.contains($0) }) {
                offenders.append("bs spoken form \(spoken)")
            }
        }

        offenders += try Self.stringsConstantsReachingTheSpokenChannel(forbidden: forbidden)

        #expect(offenders.isEmpty, "typographic characters in the spoken channel: \(offenders)")
    }

    private static func stringsConstantsReachingTheSpokenChannel(
        forbidden: Set<Character>
    ) throws -> [String] {
        let shownThatNeverAnnounces: Set<String> = ["weekdaySeparator"]
        let proseTheParserCannotRead: Set<String> = []

        var offenders: [String] = []
        let constants = try declaredStringConstants()
        for (name, value) in constants.sorted(by: { $0.key < $1.key })
        where value.contains(where: { forbidden.contains($0) }) {
            if name.hasSuffix("Spoken") {
                offenders.append("\(name) is spoken and carries typographic punctuation")
            } else if !shownThatNeverAnnounces.contains(name),
                      !constants.keys.contains("\(name)Spoken") {
                offenders.append("\(name) is announced as shown and has no spoken form")
            }
        }
        for name in try unparsedConstantNames() where !proseTheParserCannotRead.contains(name) {
            offenders.append("\(name) is a `static let` this sweep cannot read; classify it")
        }
        return offenders
    }

    /// `Strings` constants with a single-line literal value, parsed from source
    /// because `Mirror` can't enumerate static properties.
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

    private static func singleLineLiteral(_ tail: String) -> String? {
        guard let opening = tail.firstIndex(of: "\""),
              !String(tail[opening...]).hasPrefix("\"\"\""),
              let closing = closingQuote(in: tail, from: tail.index(after: opening))
        else { return nil }
        return String(tail[opening ..< closing])
    }

    private static func unparsedConstantNames() throws -> [String] {
        let parsed = try declaredStringConstants()
        return try sourceLines()
            .compactMap { constantName(in: $0.trimmingCharacters(in: .whitespaces)) }
            .filter { parsed[$0] == nil }
    }

    private static func sourceLines() throws -> [String] {
        try String(
            contentsOf: Repository.root.appendingPathComponent("NepalKit/Strings.swift"),
            encoding: .utf8
        ).split(separator: "\n").map(String.init)
    }

    private static func constantName(in line: String) -> String? {
        guard line.hasPrefix("static let ") else { return nil }
        let rest = line.dropFirst("static let ".count)
        let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        return name.isEmpty ? nil : String(name)
    }

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

    @Test func spokenSupportedRangeAvoidsTheEnDash() {
        let spoken = Strings.supportedRangeSpoken(1975 ... 2084)
        #expect(!spoken.contains("\u{2013}"), "en dash survives in the spoken range: \(spoken)")
        #expect(spoken == "1975 to 2084 BS")
    }

    @Test func gregorianAnnouncementFoldsInTheWeekdayWhenThereIsOne() {
        let date = GregorianDate(year: 2026, month: 9, day: 27)

        #expect(SpokenDate.gregorianAnnouncement(date: date, weekday: "Sunday") == "27 September 2026, Sunday")
        #expect(SpokenDate.gregorianAnnouncement(date: date, weekday: nil) == "27 September 2026")
    }
}
