// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel

/// Dates and numbers as a screen reader should speak them.
///
/// Use these for an accessibility label, never for what is shown. Speech
/// engines do not reliably read Devanagari digits: they come out as silence,
/// as separate digits, or as a stray character. So the spoken forms always
/// use Latin digits, while the month name stays in the chosen style. Where
/// the visible text already uses Latin digits it can be spoken as is.
public enum SpokenDate {
    /// A Bikram Sambat date to speak, such as "27 Ashoj 2083".
    public static func bikramSambat(_ date: BikramSambatDate, monthNames: MonthNameStyle) -> String {
        date.formatted(DisplaySettings(digits: .latin, monthNames: monthNames))
    }

    /// A Gregorian date to speak, such as "27 September 2026".
    public static func gregorian(_ date: GregorianDate) -> String {
        date.formatted(digits: .latin)
    }

    /// A number to speak, whatever script it is shown in.
    public static func number(_ value: Int) -> String {
        DigitScript.latin.format(value)
    }

    /// A festival's name in the given style, with any Devanagari digits in it
    /// spoken as Latin ones. Some Panchanga names contain numbers
    /// ("ने.सं.११४७ प्रारम्भ").
    public static func festival(_ festival: Festival, monthNames: MonthNameStyle) -> String {
        String(festival.name(style: monthNames).map { character in
            guard ("०" ... "९").contains(character), let value = character.wholeNumberValue else { return character }
            return Character(number(value))
        })
    }
}
