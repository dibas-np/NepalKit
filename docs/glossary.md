# Glossary

The terms NepalKit's code, interface, and docs use, and the words to avoid.

## Language

**Bikram Sambat**:
Nepal's official calendar.
_Avoid_: Nepali calendar, BS date

_Accepted exception_: the Siri intent title and phrases say "Nepali date" (`TodayInBikramSambatIntent.swift`, `NepalKitShortcuts.swift`, `Strings.swift`), because that is what a person says aloud. Everywhere else the terms above apply.

**Gregorian**:
The civil calendar used internationally. NepalKit converts dates to and from it.
_Avoid_: English date, AD date

**Nepal Time**:
Nepal's time zone, UTC+5:45.
_Avoid_: Nepali time, Kathmandu time

**Nepali Patro**:
The officially approved calendar for one Bikram Sambat year. The Nepal Panchanga Nirnayak Samiti publishes it as the national Panchanga, so the docs and `FestivalCalendar.panchanga` call the published document the Panchanga.
_Avoid_: almanac, Nepali calendar book

## Display

**Digit script**:
The display setting that chooses Latin digits (0123456789) or Devanagari digits (०१२३४५६७८९) for every number NepalKit shows. It is separate from the month-name setting.
_Avoid_: number format, locale

**Month-name setting**:
The display setting that chooses Nepali or transliterated English for Bikram Sambat month names and weekday names. It changes how dates read, not the language of the rest of the interface.
_Avoid_: language setting, locale setting

**Gregorian month name**:
The name of a Gregorian month. It is always English, whatever the month-name setting.
_Avoid_: localized month name, translated month name

**Weekday**:
The day of the week a date falls on, named in the language the month-name setting picks and shown once per date. The Bikram Sambat and Gregorian forms of a date share one weekday, so it belongs to neither calendar.
_Avoid_: BS weekday, AD weekday

## Calendar data

**Today**:
The current date in Nepal Time. On the Mac, the user can choose their own time zone instead. The Watch always uses Nepal Time. A date that the user enters for conversion is not "today". NepalKit converts only its year, month, and day, with no time zone.
_Avoid_: current date

**Supported range**:
The Bikram Sambat years that the bundled dataset converts in both directions. The dataset declares the range in `CalendarDataset.supportedRange`, and NepalKit never converts past it.
_Avoid_: product boundary, date range, supported years

**Range boundary state**:
What NepalKit shows when the current date is past the supported range: "Bikram Sambat date unavailable" and the last supported year, beside the Gregorian date and Nepal Time. It is an expected result, not an error.
_Avoid_: error state, unavailable date, out-of-range
