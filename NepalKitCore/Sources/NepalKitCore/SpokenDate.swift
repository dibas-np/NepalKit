// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// Spoken representations of the app's date text, for VoiceOver.
///
/// **This changes what is *said*, never what is *shown*.** The visual date
/// always renders exactly as the user configured it — Devanagari digits stay
/// Devanagari on screen. Only the accessibility channel differs, which is the
/// distinction this whole file rests on: fixing a speech problem by changing the
/// visual date would be fixing the wrong channel.
///
/// ## Why the digits are the problem
///
/// The app renders `२७ असोज २०८३`. A month name in a script the active
/// VoiceOver voice covers is readable; **Devanagari digits are not reliably
/// spoken**, and they are the part most likely to come out as silence, as
/// "two seven", or as a stray character. So the spoken form uses Latin digits
/// while keeping the month name in the user's chosen language, which is the
/// semantically important half and which a matching voice reads correctly.
///
/// Where a user has chosen Latin digits the spoken form is identical to the
/// visual one, and no override is applied — announcing something different from
/// what is on screen, without cause, would be its own defect.
///
/// This is a judgement about speech, not a measurement of it. Spoken output is a
/// platform rendering property; the platform side is checked by walking the real
/// accessibility tree, and the transformation itself is covered by
/// `NepalKitCoreTests.SpokenDateTests`.
public enum SpokenDate {
    /// The spoken form of a Bikram Sambat date, e.g. `27 Ashoj 2083`.
    public static func bs(_ bs: BSDay, monthNames: MonthNameStyle) -> String {
        "\(formatNumber(bs.day, digits: .latin)) \(monthName(month: bs.month, style: monthNames)) \(formatNumber(bs.year, digits: .latin))"
    }

    /// The spoken form of a Gregorian date, e.g. `27 September 2026`.
    ///
    /// Gregorian month names are always English on every surface and in every
    /// display combination (CONTEXT.md), so only the digits can ever differ.
    public static func ad(_ ad: GADay) -> String {
        "\(formatNumber(ad.day, digits: .latin)) \(gregorianMonthName(ad.month)) \(formatNumber(ad.year, digits: .latin))"
    }

    /// The spoken form of a Gregorian date with its weekday, for the popover's
    /// second line. The weekday is optional because it is a separate lookup
    /// that can fail, not because the date can.
    public static func gregorianAnnouncement(date: GADay, weekday: String?) -> String {
        guard let weekday else { return ad(date) }
        return "\(ad(date)), \(weekday)"
    }

    /// A number as it should be spoken, whatever script it is drawn in.
    public static func number(_ value: Int) -> String {
        formatNumber(value, digits: .latin)
    }
}
