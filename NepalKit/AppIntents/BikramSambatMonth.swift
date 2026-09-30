// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

/// The twelve Bikram Sambat months as Siri resolves them by voice.
///
/// Raw values are the dataset's month numbers, so a case converts to the
/// dataset world with no translation step. Titles are the app's canonical
/// transliterations (`NepalKitCore.transliteratedMonthNames`); synonyms carry
/// the variants people actually say, plus the Devanagari spellings, which
/// serve text matching in Shortcuts/Spotlight — spoken matching rides the
/// Latin titles and synonyms. Every string is a build-time literal, because
/// App Intents metadata is extracted from source (wayfinder ticket 01). The
/// synonym table is ticket 02's decision, adopted verbatim; "Manxsir" was
/// explicitly rejected there and must not reappear.
nonisolated enum BikramSambatMonth: Int, AppEnum, CaseIterable {
    case baisakh = 1
    case jestha = 2
    case ashar = 3
    case shrawan = 4
    case bhadra = 5
    case ashoj = 6
    case kartik = 7
    case mangsir = 8
    case poush = 9
    case magh = 10
    case falgun = 11
    case chaitra = 12

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Bikram Sambat month", synonyms: ["Nepali month", "BS month"]
    )

    static let caseDisplayRepresentations: [BikramSambatMonth: DisplayRepresentation] = [
        .baisakh: DisplayRepresentation(
                title: "Baisakh",
                synonyms: ["Baishakh", "Baisak", "Vaishakh", "Vaishakha", "Vaisakha", "बैशाख", "वैशाख"]
            ),
            .jestha: DisplayRepresentation(
                title: "Jestha",
                synonyms: ["Jeth", "Jet", "Jyeshtha", "Jyestha", "जेठ", "ज्येष्ठ"]
            ),
            .ashar: DisplayRepresentation(
                title: "Ashar",
                synonyms: ["Asar", "Aso", "Ashadh", "Ashadha", "Aashadh", "असार", "आषाढ", "आषाढ़"]
            ),
            .shrawan: DisplayRepresentation(
                title: "Shrawan",
                synonyms: ["Saun", "Sawan", "Shan", "Shravan", "Shravana", "Sravan", "Srawan", "साउन", "श्रावण"]
            ),
            .bhadra: DisplayRepresentation(
                title: "Bhadra",
                synonyms: ["Bhadau", "Bhado", "Bhadaw", "Bhadrapad", "Bhadrapada", "भदौ", "भाद्र", "भाद्रपद"]
            ),
            .ashoj: DisplayRepresentation(
                title: "Ashoj",
                synonyms: ["Asoj", "Asojh", "Ashwin", "Ashwina", "Ashvin", "असोज", "आश्विन", "अश्विन"]
            ),
            .kartik: DisplayRepresentation(
                title: "Kartik",
                synonyms: ["Kattik", "Katti", "Kartika", "Kaartik", "कात्तिक", "कार्तिक"]
            ),
            .mangsir: DisplayRepresentation(
                title: "Mangsir",
                synonyms: ["Manger", "Margesir", "Mangser", "Margashirsha", "Margasira", "मंसिर", "मङ्सिर", "मार्गशीर्ष"]
            ),
            .poush: DisplayRepresentation(
                title: "Poush",
                synonyms: ["Paush", "Push", "Pus", "Poos", "Pausha", "पुस", "पुष", "पौष"]
            ),
            .magh: DisplayRepresentation(
                title: "Magh",
                synonyms: ["Maagh", "Maag", "Magha", "माघ"]
            ),
            .falgun: DisplayRepresentation(
                title: "Falgun",
                synonyms: ["Phagun", "Fagun", "Phagan", "Phalgun", "Phalguna", "फागुन", "फाल्गुण", "फाल्गुन"]
            ),
            .chaitra: DisplayRepresentation(
                title: "Chaitra",
                synonyms: ["Chait", "Chet", "चैत", "चैत्र"]
            ),
    ]

    /// Every string a typed query can name this month by: its title plus all
    /// synonyms. Matching must be exact (case-insensitive) — the table
    /// deliberately contains near-collisions ("Aso" for Ashar, "Asoj" for
    /// Ashoj) that substring matching would misroute.
    var candidateStrings: [String] {
        let representation = Self.caseDisplayRepresentations[self]
        return [representation?.title.key ?? ""] + (representation?.synonyms.map { $0.key } ?? [])
    }
}
