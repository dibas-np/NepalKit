// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

nonisolated extension Strings {
    static func publicHoliday(_ scope: PublicHoliday.Scope, monthNames: MonthNameStyle) -> String {
        guard let wording = publicHolidayWording[scope] else {
            preconditionFailure("No public-holiday wording for \(scope)")
        }
        return monthNames == .nepali ? wording.nepali : wording.english
    }

    static func publicHolidaySpoken(_ scope: PublicHoliday.Scope, monthNames: MonthNameStyle) -> String {
        let phrase = publicHoliday(scope, monthNames: monthNames)
        return phrase.prefix(1).lowercased() + phrase.dropFirst()
    }

    static func todayFestivalLine(_ names: [String], isPublicHoliday: Bool, monthNames: MonthNameStyle) -> String {
        festivalNames(names + (isPublicHoliday ? [publicHoliday(.nationwide, monthNames: monthNames)] : []))
    }

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

    static func festivalsAndHolidaysListedOnly(for years: Set<Int>, digits: DigitScript) -> String {
        "Festivals and holidays are listed for \(yearList(years, digits: digits)) BS only."
    }

    static func festivalsListedOnly(for years: Set<Int>, digits: DigitScript) -> String {
        "Festivals are listed for \(yearList(years, digits: digits)) BS only."
    }

    static func holidaysListedOnly(for years: Set<Int>, digits: DigitScript) -> String {
        "Public holidays are listed for \(yearList(years, digits: digits)) BS only."
    }

    static func monthGridProvisionalYear(_ year: Int, digits: DigitScript) -> String {
        "\(digits.format(year)) BS is a projection, not yet in the official Nepali Patro."
    }

    private static func yearList(_ years: Set<Int>, digits: DigitScript) -> String {
        let sorted = years.sorted().map { digits.format($0) }
        guard let last = sorted.last else { return "" }
        return sorted.count == 1 ? last : "\(sorted.dropLast().joined(separator: ", ")) and \(last)"
    }
}
