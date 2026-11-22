// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

/// Every string is a literal because App Intents metadata
/// is extracted from source.
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

    var candidateStrings: [String] {
        let representation = Self.caseDisplayRepresentations[self]
        return [representation?.title.key ?? ""] + (representation?.synonyms.map { $0.key } ?? [])
    }
}
