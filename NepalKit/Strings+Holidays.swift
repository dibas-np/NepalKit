// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// The public-holiday wording: what the day's details and today's line say
/// about the gazette's holidays. Kept apart from `Strings` by topic.
///
/// Unlike the rest of the UI, these follow the month-name setting, as the
/// festival names beside them do: a reader with Nepali month names reads the
/// festival in Nepali, and a holiday line in English under it would be the one
/// line in the wrong language.
nonisolated extension Strings {
    /// One line per scope in the day's details: who the day is a holiday for.
    static func publicHoliday(_ scope: PublicHoliday.Scope, monthNames: MonthNameStyle) -> String {
        guard let wording = publicHolidayWording[scope] else {
            preconditionFailure("No public-holiday wording for \(scope)")
        }
        return monthNames == .nepali ? wording.nepali : wording.english
    }

    /// The same phrase as a clause in a spoken list, after a date and the
    /// festival names: "…, Vijaya Dashami, public holiday". Only English has
    /// a capital to drop.
    static func publicHolidaySpoken(_ scope: PublicHoliday.Scope, monthNames: MonthNameStyle) -> String {
        let phrase = publicHoliday(scope, monthNames: monthNames)
        return phrase.prefix(1).lowercased() + phrase.dropFirst()
    }

    /// Today's line under the hero date: the festivals, then "Public holiday"
    /// on a nationwide holiday. A limited holiday is left to the day's
    /// details, where there is room to say who it is for.
    static func todayFestivalLine(_ names: [String], isPublicHoliday: Bool, monthNames: MonthNameStyle) -> String {
        festivalNames(names + (isPublicHoliday ? [publicHoliday(.nationwide, monthNames: monthNames)] : []))
    }

    /// Each scope's phrase, English then Nepali. A table rather than a
    /// switch per language, which keeps the two side by side for checking;
    /// the tests hold it to every case of the scope.
    private static let publicHolidayWording: [PublicHoliday.Scope: (english: String, nepali: String)] = [
        .nationwide: ("Public holiday", "सार्वजनिक बिदा"),
        .newarCommunity: ("Public holiday for the Newar community", "नेवार समुदायका लागि बिदा"),
        .kathmanduValley: ("Public holiday in Kathmandu Valley", "काठमाडौं उपत्यकामा बिदा"),
        .womenEmployees: ("Public holiday for women employees", "महिला कर्मचारीका लागि बिदा"),
        .womenObservingJitiya: ("Public holiday for women employees who observe Jitiya", "जितिया मनाउने महिला कर्मचारीका लागि बिदा"),
        .educationalInstitutions: ("Holiday for educational institutions", "शिक्षण संस्थाका लागि बिदा"),
        .hillAndMountainDistricts: ("Public holiday in hill and mountain districts", "हिमाली र पहाडी जिल्लामा बिदा"),
        .taraiDistricts: ("Public holiday in Tarai districts", "तराईका जिल्लामा बिदा"),
        .duraCommunity: ("Public holiday for the Dura community", "दुरा समुदायका लागि बिदा"),
        .employeesWithDisabilities: ("Public holiday for employees with disabilities", "अपाङ्गता भएका कर्मचारीका लागि बिदा"),
        .kiratCommunity: ("Public holiday for the Kirat community", "किराँत धर्मावलम्बीका लागि बिदा"),
        .sikhCommunity: ("Public holiday for the Sikh community", "सिख धर्मावलम्बीका लागि बिदा"),
        .gauraRegion: ("Public holiday where Gaura is observed", "गौरा पर्व मनाउने क्षेत्रमा बिदा"),
    ]
}
