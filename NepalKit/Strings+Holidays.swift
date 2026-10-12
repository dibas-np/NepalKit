// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// The public-holiday wording for the day's details and today's line.
///
/// Unlike the rest of the UI, these follow the month-name setting, as the
/// festival names beside them do, so they are never the one line in the
/// wrong language.
nonisolated extension Strings {
    /// One line per scope in the day's details: who the day is a holiday for.
    static func publicHoliday(_ scope: PublicHoliday.Scope, monthNames: MonthNameStyle) -> String {
        guard let wording = publicHolidayWording[scope] else {
            preconditionFailure("No public-holiday wording for \(scope)")
        }
        return monthNames == .nepali ? wording.nepali : wording.english
    }

    /// The phrase as a clause in a spoken list: "…, Vijaya Dashami, public
    /// holiday". Only English has a capital to drop.
    static func publicHolidaySpoken(_ scope: PublicHoliday.Scope, monthNames: MonthNameStyle) -> String {
        let phrase = publicHoliday(scope, monthNames: monthNames)
        return phrase.prefix(1).lowercased() + phrase.dropFirst()
    }

    /// Today's line under the hero: the festivals, then "Public holiday" on a
    /// nationwide holiday. A limited holiday is left to the day's details.
    static func todayFestivalLine(_ names: [String], isPublicHoliday: Bool, monthNames: MonthNameStyle) -> String {
        festivalNames(names + (isPublicHoliday ? [publicHoliday(.nationwide, monthNames: monthNames)] : []))
    }

    /// Each scope's phrase, English then Nepali, side by side for checking;
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

    /// Under the month grid when the shown year has neither list, so it does
    /// not look like a year with no festivals. Names the years that are listed,
    /// so it is true under any year.
    static func festivalsAndHolidaysListedOnly(for years: Set<Int>, digits: DigitScript) -> String {
        "Festivals and holidays are listed for \(yearList(years, digits: digits)) BS only."
    }

    /// Only the festival list is missing: the Panchanga and the gazette are
    /// published at different times.
    static func festivalsListedOnly(for years: Set<Int>, digits: DigitScript) -> String {
        "Festivals are listed for \(yearList(years, digits: digits)) BS only."
    }

    /// Only the holiday list is missing.
    static func holidaysListedOnly(for years: Set<Int>, digits: DigitScript) -> String {
        "Public holidays are listed for \(yearList(years, digits: digits)) BS only."
    }

    /// Under the month grid when the shown year is a provisional projection.
    static func monthGridProvisionalYear(_ year: Int, digits: DigitScript) -> String {
        "\(formatNumber(year, digits: digits)) BS is a projection, not yet in the official Nepali Patro."
    }

    /// "2083", "2083 and 2084", "2083, 2084 and 2085". Joined by hand, as
    /// `provisionalYearsNote` is, not with Foundation list formatting.
    private static func yearList(_ years: Set<Int>, digits: DigitScript) -> String {
        let sorted = years.sorted().map { formatNumber($0, digits: digits) }
        guard let last = sorted.last else { return "" }
        return sorted.count == 1 ? last : "\(sorted.dropLast().joined(separator: ", ")) and \(last)"
    }
}
