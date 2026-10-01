# Siri answers in Bikram Sambat — Spec

Status: ready-for-agent

> Provenance: assembled from the resolved tickets of the wayfinder effort
> **Siri answers in Bikram Sambat** (map: `.scratch/siri-bikram-sambat/map.md`,
> local and untracked by design). The research findings live at
> `docs/research/macos26-app-intents-for-menubar-apps.md` on the
> `research/macos26-app-intents` branch; the on-device prototype is commits
> `9c98cc1` + `33cae8d` on `prototype/siri-on-macos` (based on the research
> branch). Those are history. This document is the handoff: it wins where
> summaries disagree with it, and nothing in it reopens a settled ticket
> without new evidence.

## Problem statement

NepalKit converts dates; Siri does not. Asked "what is today's Nepali date",
macOS 26's Siri answers from web knowledge — "late June or early July" — where
the app's dataset produces "Sunday, 29 June 2025", a named weekday, and a
month length it can prove. The prototype demonstrated the gap precisely: Siri
AI, asked to convert, abstained and invented "the app doesn't support in-app
search" as its excuse. This spec adds the App Intents surface that puts the
dataset's answers in Siri, Shortcuts, and Spotlight.

## Solution

Three background App Intents in the app target, backed entirely by
`NepalKitCore` — a today query, and one conversion in each direction —
surfaced through Siri and the Shortcuts app on macOS 26. Voice serves the
parameterless query; Shortcuts' parameter forms serve the conversions. The
dataset remains the only authority for every number the feature speaks.

## Terminology

`CONTEXT.md` governs: **Bikram Sambat**, **Gregorian**, **Today**, **Range
boundary state**. One surface-specific exception, settled with the user:
**"Nepali date" appears only inside Siri phrases, as spoken vocabulary** —
never in UI, dialogs, docs, or code identifiers. Users say "Nepali date";
the product says Bikram Sambat.

## The intents

All three declare `supportedModes: .background` (the macOS 26 replacement for
`openAppWhenRun`), complete parameter summaries, and identifiers fixed by
ticket 02. The project compiles with default MainActor isolation, and the
intents ride it — their work is pure, synchronous, and fast; do not promise
otherwise in comments.

### 1. `TodayInBikramSambatIntent`

No parameters. Anchored to **Nepal Time** via `todayBS(now:in:)`: "today"
means Nepal's current calendar date — the glossary's Today entry, and the
only query in the product anchored to an instant.

Returns a `BikramSambatDate` entity plus the dialog
`Today is <weekday>, <BS date>.`

### 2. `GregorianToBikramSambatIntent`

`@Parameter(title: "Date", requestValueDialog: …) var date: Date`.

The semantic decision (ticket 02, user-confirmed): the resolved instant is
read as **the calendar day Siri named, in the user's current time zone**;
time-of-day is discarded — conversions are day-granular. Only *today* is
Nepal-Time-anchored; a named conversion input is a calendar day as spoken,
independent of Nepal Time. A full date is required; Siri prompts when
missing. Which time zone Siri actually resolves into was unverifiable by
voice (see capability matrix); the decision — the named day survives —
holds under any mechanism, because the day is extracted from the resolved
instant and re-validated against the dataset.

Returns a `BikramSambatDate` entity plus the dialog `<weekday>, <BS date>.`

### 3. `BikramSambatToGregorianIntent`

`day: Int`, `month: BikramSambatMonth`, `year: Int` — a Bikram Sambat date is
a civil day, not a Gregorian instant, so no `Date` parameter can express it.

Returns a native `Date` (the Gregorian civil day at **noon UTC**, chosen so
downstream date math lands on the named day from UTC−12 inclusive through
UTC+12 exclusive; at UTC+12 and beyond it falls on the following local day,
as `NoonUTCTests` pins) plus the dialog `<weekday>, <Gregorian date>.`
Gregorian month names are always English, per the glossary.

## The Bikram Sambat month enum

`BikramSambatMonth: Int, AppEnum` — raw values 1–12, matching dataset month
numbers directly. **Every string is a build-time literal**: App Intents
metadata is extracted from source, and nothing may call into the dataset at
declaration time. Titles are the app's canonical transliterations from
`NepalKitCore` (`transliteratedMonthNames`); synonyms carry the variants
people actually say plus the Devanagari spellings, which serve text matching
in Shortcuts/Spotlight — spoken matching rides the Latin titles. The table is
ticket 02's decision, verbatim; "Manxsir" was explicitly rejected there and
must not reappear.

| # | Title | Synonyms |
|---|-------|----------|
| 1 | Baisakh | Baishakh, Baisak, Vaishakh, Vaishakha, Vaisakha, बैशाख, वैशाख |
| 2 | Jestha | Jeth, Jet, Jyeshtha, Jyestha, जेठ, ज्येष्ठ |
| 3 | Ashar | Asar, Aso, Ashadh, Ashadha, Aashadh, असार, आषाढ, आषाढ़ |
| 4 | Shrawan | Saun, Sawan, Shan, Shravan, Shravana, Sravan, Srawan, साउन, श्रावण |
| 5 | Bhadra | Bhadau, Bhado, Bhadaw, Bhadrapad, Bhadrapada, भदौ, भाद्र, भाद्रपद |
| 6 | Ashoj | Asoj, Asojh, Ashwin, Ashwina, Ashvin, असोज, आश्विन, अश्विन |
| 7 | Kartik | Kattik, Katti, Kartika, Kaartik, कात्तिक, कार्तिक |
| 8 | Mangsir | Manger, Margesir, Mangser, Margashirsha, Margasira, मंसिर, मङ्सिर, मार्गशीर्ष |
| 9 | Poush | Paush, Push, Pus, Poos, Pausha, पुस, पुष, पौष |
| 10 | Magh | Maagh, Maag, Magha, माघ |
| 11 | Falgun | Phagun, Fagun, Phagan, Phalgun, Phalguna, फागुन, फाल्गुण, फाल्गुन |
| 12 | Chaitra | Chait, Chet, चैत, चैत्र |

The type is titled "Bikram Sambat month" with synonyms "Nepali month" and
"BS month" (spoken synonym only). Near-collisions across cases ("Aso" in
month 3 vs the title "Asoj" in month 6, "Shan" vs "Shrawan") and
English-word synonyms ("Push", "Manger") are accepted deliberately:
synonyms are consulted only while Siri resolves a month parameter for these
intents, so cross-intent hijack is not a risk.

## The `BikramSambatDate` entity

Properties `year: Int`, `month: BikramSambatMonth`, `day: Int`,
`weekday: String?` — the fields an automation can read. Text identity is
`"year-month-day"` (dataset month number), with an `EntityStringQuery` that
parses typed input like "15 Ashar 2082" against titles and synonyms
(Latin digits only; Devanagari digit input is left to the live Shortcuts
UI). Its `displayRepresentation` renders with the user's **actual display
settings** — Devanagari digits included — because it is shown, not said.

## Dialogs and displays: the split

One conceptual distinction covers VoiceOver, Siri, and Shortcuts alike
(`SpokenDate.swift` already documents it for VoiceOver; Siri is the same
judgment, one channel over):

- **Dialogs** (spoken, and spoken-form wherever Siri renders text) use
  `SpokenDate` conventions: Latin digits always, the user's month-name
  setting for month and weekday names, weekday included.
- **Entity displays** (rendered by Shortcuts/Spotlight) use the user's real
  `DisplaySettings` — Devanagari digits and all.

`SettingsStore()` reads cold from `UserDefaults.standard`: no UI launch, no
MainActor hop. **The store must be marked `nonisolated`** — the project's
default MainActor isolation otherwise makes it unreachable from intent code;
the prototype made this change and the spec ratifies it. Unset keys fall
back to the store's own defaults (transliterated, Latin).

## Failure behavior

`parameter → runtime validation → dataset → established range/invalid-date
behavior`. **The dataset supplies every number** — boundary dates and month
lengths come from `CalendarDataset` (`supportedRange`, `monthLengths(for:)`,
`anchorAD`, `gregorianEnd`); intent code hard-codes none of them. No
`supportedValues` arrays: no 110-item Shortcuts picker, no duplicated
authority in code.

The four shapes, with the wording fixed by ticket 03:

1. **Today beyond the range** (after the dataset's Gregorian end): "NepalKit's
   Bikram Sambat data covers up to the year 2084. Today is <Gregorian
   today>." — the Gregorian side stays answerable, exactly as the UI's
   range-boundary state does (`weekday(of:)` deliberately survives past the
   range; use it).
2. **Gregorian → Bikram Sambat, out of range**: the statement naming the BS
   range and the Gregorian boundary on the exceeded side ("…covers 1975
   through 2084 — up to 12 April 2028. That date is outside it."), mirrored
   for dates before the anchor.
3. **Bikram Sambat → Gregorian, out of range**: the full boundary in both
   calendars ("…1975 through 2084 — 13 April 1918 to 12 April 2028…").
4. **Invalid Bikram Sambat date**: "There is no 31 Kartik 2082 — Kartik 2082
   has 30 days." (The prototype corrected ticket 03's example: "32 Ashar
   2082" is a *valid* date — Ashar 2082 has 32 days. Test with 31 Kartik.)

A Gregorian input that names no civil day (30 February) gets the parallel
month-length statement before the range check. Thrown failures carry the
dialog on a `SiriIntentError` (an `Error` that is also `LocalizedError` and
`CustomLocalizedStringResourceConvertible`); whether each macOS surface
shows the thrown message verbatim rather than a generic one is re-verified
during implementation via the Shortcuts UI, which is the reliable path.

## Phrases

**Phrases identify the intent; parameters supply the date.** A `Date` can
never ride in a phrase (only finite-set values may), and a month enum in one
would spawn generated shortcuts against the ten-shortcut cap — so all three
intents take parameterless phrases and Siri gathers dates conversationally.
Seven phrases, three App Shortcuts, every phrase carrying
`\(.applicationName)`, English only (Nepali is not a Siri language):

- Today: **"What is today's Nepali date with \(.applicationName)"**
  (primary — tile label), "What is my \(.applicationName) date", "What is
  today in Bikram Sambat with \(.applicationName)"
- Gregorian → BS: "Convert a date to Bikram Sambat with
  \(.applicationName)", "Use \(.applicationName) to convert to Bikram
  Sambat"
- BS → Gregorian: "Convert a Bikram Sambat date to Gregorian with
  \(.applicationName)", "Use \(.applicationName) to convert from Bikram
  Sambat"

`NepalKitShortcuts.updateAppShortcutParameters()` is called in the App's
`init` — the prototype showed parameterless shortcuts did **not** register
on install alone.

## The `AppShortcuts.xcstrings` requirement

The app shipped with zero localizations, and App Shortcuts phrases load per
app-localization: **a bundle with none registers nothing**, silently, while
build-time metadata extraction still succeeds. The catalog carries ten keys
(seven phrase templates with `${applicationName}` — dollar included — and
three short titles), each with an English localization mirroring the source.
It must stay valid JSON; Xcode fails the build otherwise.

## What macOS 26 actually supports

Verified on-device (prototype, ticket 04). The spec ships this reality, not
the aspiration:

| Surface | Parameterless (today) | Parameterized (conversions) |
|---|---|---|
| Siri, natural phrasing | Works | Abstains — Siri AI answers from web with an invented excuse |
| Siri, verbatim phrase | Works | Routes, then fails to fill parameters from speech (both parameter shapes) |
| Spotlight | Appears and runs | Not surfaced, despite complete parameter summaries |
| Shortcuts app | — | Works: action library + parameter forms |

The product story: **voice owns the today query; Shortcuts and automations
own the conversions.** Voice parameter-filling is an OS behavior, not an app
defect — retest on macOS 26.x updates before treating it as permanent, and
keep the conversational parameter flow (request value dialogs) implemented,
because it costs nothing and starts working the day the OS does.

## Registration requirements

What it took to make the system see the shortcuts — all real, all verified:

1. Install in `/Applications` (bundle id resolution).
2. **Login/logout.** App Shortcuts ingest at login; no daemon kick, push, or
   registration call substitutes for it.
3. Developer ID signing with hardened runtime (ad-hoc Debug builds are
   suspect for voice routing).
4. `updateAppShortcutParameters()` at every App init.
5. The `AppShortcuts.xcstrings` localization above.

Release-engineering note: the machine carried 90+ stale LaunchServices
registrations for the bundle id from pipeline and test builds, and
`lsregister -u` mostly refuses dead paths. **The release pipeline must build
under a stable path or unregister its temp builds** (`lsregister -u` while
they still exist); the swamp made bundle-id resolution ambiguous for system
services.

## Discoverability

Two surfaces (ticket 06); the popover footer stays untouched — icon-only, no appropriate space, and the popover remains focused on the calendar/date experience:

- **Settings → General → "Siri & Shortcuts"** (General is the landing tab): leads with the expectation-setting sentence — *"Ask Siri for today's Nepali date; run the conversions from Shortcuts."* — then lists the three capabilities with their phrases as plain text. `SiriTipView` does not exist on macOS (verified against the installed SDK's swiftinterface), so phrases are taught as text. The sentence is load-bearing: the prototype established that Siri's current voice parameter-filling and what the same App Intents expose to Shortcuts are different capabilities, and the UI must not imply conversational conversions work by voice today.
- **Launch release notes**: a paragraph announcing the feature, through the existing release-notes pipeline.

No popover hint, no transient onboarding.

## Testing expectations

- Unit tests (app layer): intent logic against the dataset — today anchoring
  to Nepal Time; named-day extraction for Gregorian input; round-trip through
  `BikramSambatDate`; every failure shape's wording with dataset-derived
  numbers (31 Kartik 2082 → 30 days; year 2090 → range statement); entity
  id round-trip and query parsing.
- On-device, once: the Siri today probe ("What is today's Nepali date with
  NepalKit" → "Today is Wednesday, 14 Ashoj 2083."-style answer) and one
  Shortcuts-form conversion ("15 Ashar 2082" → "Sunday, 29 June 2025"),
  plus one failure path through the Shortcuts UI to observe how the thrown
  dialog surfaces.
- The prototype's expected-answer table (computed independently from the
  dataset) lives in ticket 04 and doubles as a test oracle.

## Out of scope

Nepal Time voice queries (Siri's world clock answers them); Spotlight,
Action button, and Control Center *surfacing* beyond what registration gives
for free; iOS/iPadOS (intent design stays cross-platform-compatible but no
target is created); "today in Gregorian" (Siri answers natively);
multi-turn follow-ups ("what about tomorrow?") until the single-turn surface
has shipped; feature implementation itself — this spec hands off to the
normal issue flow.
