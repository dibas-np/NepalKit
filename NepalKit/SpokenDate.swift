import NepalKitCore

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
/// `SpokenDateTests`.
enum SpokenDate {
    /// The spoken form of a Bikram Sambat date, e.g. `27 Ashoj 2083`.
    static func bs(_ bs: BSDay, monthNames: MonthNameStyle) -> String {
        "\(formatNumber(bs.day, digits: .latin)) \(monthName(month: bs.month, style: monthNames)) \(formatNumber(bs.year, digits: .latin))"
    }

    /// The spoken form of a Gregorian date, e.g. `27 September 2026`.
    ///
    /// Gregorian month names are always English on every surface and in every
    /// display combination (CONTEXT.md), so only the digits can ever differ.
    static func ad(_ ad: GADay) -> String {
        "\(formatNumber(ad.day, digits: .latin)) \(gregorianMonthNames[ad.month - 1]) \(formatNumber(ad.year, digits: .latin))"
    }

    /// The spoken form of a Gregorian date with its weekday, for the popover's
    /// second line. The weekday is optional because it is a separate lookup
    /// that can fail, not because the date can.
    static func gregorianAnnouncement(date: GADay, weekday: String?) -> String {
        guard let weekday else { return ad(date) }
        return "\(ad(date)), \(weekday)"
    }

    /// A number as it should be spoken, whatever script it is drawn in.
    static func number(_ value: Int) -> String {
        formatNumber(value, digits: .latin)
    }

    /// A full announcement for the menu-bar extra.
    ///
    /// The hardest surface in the app, and the ticket's most visible one: it is
    /// the only thing a blind user meets before opening anything. A bare date
    /// like "11 Ashoj" says nothing about *which* app it belongs to, and someone
    /// navigating by menu-bar extras is relying on this one string entirely.
    /// Naming the app costs a word and makes the item identifiable out of
    /// context.
    static func menuBar(today: BSDay?, monthNames: MonthNameStyle) -> String {
        guard let today else {
            // Past the supported range the label is a marker, not a date, and a
            // bare "n/a" spoken alone is meaningless — it reads as a broken
            // item. Say what actually happened instead.
            return "\(Strings.appNameForSpeech), \(Strings.spokenDateBeyondRange)"
        }
        return "\(Strings.appNameForSpeech), \(bs(today, monthNames: monthNames))"
    }
}
