# NepalKit

A macOS menu-bar utility giving quick access to Nepal-specific date, time, and calendar information.

## Language

**Bikram Sambat**:
Nepal's official calendar system.
_Avoid_: Nepali calendar, BS date

**Gregorian**:
The internationally used civil calendar; NepalKit converts dates to and from it.
_Avoid_: English date, AD date

**Nepal Time**:
Nepal's time zone, UTC+5:45.
_Avoid_: Nepali time, Kathmandu time

**Nepali Patro**:
The officially approved annual calendar publication. NepalKit currently uses a pinned community base with explicit historical corrections and a provisional 2084 projection; see SOURCES.md and ADR-0014.
_Avoid_: Nepali calendar book

## Display

**Digit script**:
The display setting choosing between Latin 0–9 and Devanagari ०–९ for every number NepalKit renders. Independent of the month-name setting.
_Avoid_: Number format, locale

**Month-name setting**:
The display setting choosing between Nepali and transliterated English for Bikram Sambat month names and weekday names. A date-presentation choice, not a second UI language.
_Avoid_: Language setting, locale setting

**Gregorian month name**:
A Gregorian calendar month name. Always English, on every surface, in every display combination; the month-name setting does not reach it. So a date can carry a Devanagari day and year, an English month name, and a weekday name in either language at once. That combination is intentional, not mixed display.
_Avoid_: Localized month name, translated month name

**Weekday**:
The day of the week a calendar day falls on, named in the selected display language and shown once per date. A property of the date itself rather than of either calendar, so the Bikram Sambat and Gregorian representations of one day share a single weekday. Whichever line it is displayed on is presentation, not attribution.
_Avoid_: BS weekday, AD weekday

## Calendar data

**Today**:
The current calendar date in Nepal Time — an event on Nepal's clock, and the only query anchored to an instant. A date a user *names* for conversion is a different thing: a calendar day as spoken, independent of Nepal Time; only its year, month, and day matter.
_Avoid_: current date, named-date conversion

**Supported range**:
The span of Bikram Sambat years the bundled dataset converts in both directions. Declared by the dataset, never extrapolated past it. The bundled dataset is 1975–2084 BS, 1918-04-13 through 2028-04-12 Gregorian.
_Avoid_: Product boundary, date range, supported years

**Range boundary state**:
What the user sees once the current date passes the supported range: a plain statement that the Bikram Sambat date is unavailable, naming the last supported year, shown beside the Gregorian date and Nepal Time that remain answerable. Never a silent placeholder, and never a menu-bar warning badge. A range boundary state is an expected domain result and does not prevent Gregorian calendar-day progression. An unexpected calendar calculation or dataset failure is an error and must remain distinguishable from it.
_Avoid_: Error state, unavailable date, out-of-range

A supported range is a property of the bundled dataset, not a fixed product limit: the release process extends it by shipping a new dataset when newer official Patro data is published, and narrows it by shipping a new dataset when the evidence no longer supports some of its years. The current base and local exceptions are governed by ADR-0014.
