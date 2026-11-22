# Calendar data sources and licences

Dataset 2.0.1 (`CalendarDataset.v2`) covers 1975 to 2084 BS, which is 13 April
1918 through 12 April 2028 Gregorian. It is one pinned base table plus the
corrections and the 2084 projection that NepalKit keeps locally. Conversion
runs offline.

## Base reference

The month lengths for 1975 to 2083 come from one file:

- Repository: [askbuddie/bikram-sambat](https://github.com/askbuddie/bikram-sambat).
- File: [days-in-month-mapping.ts](https://github.com/askbuddie/bikram-sambat/blob/main/src/data/days-in-month-mapping.ts).
- Pinned commit: [`d3475606084141352d3bf4472c80f9051968551a`](https://github.com/askbuddie/bikram-sambat/blob/d3475606084141352d3bf4472c80f9051968551a/src/data/days-in-month-mapping.ts).
- Coverage: the file covers 1975 to 2100. NepalKit uses its rows for 1975 to 2083.
- Licence: [MIT](https://github.com/askbuddie/bikram-sambat/blob/d3475606084141352d3bf4472c80f9051968551a/LICENSE), copyright (c) 2023 Ask Buddie.

[AskBuddie-LICENSE.txt](NepalKitCore/Sources/NepalKitCore/Resources/AskBuddie-LICENSE.txt)
holds the complete upstream notice. SwiftPM copies it into the NepalKitCore
resource bundle that the apps ship. NepalKitCore, the package that holds the
table, is MIT-licensed. The rest of NepalKit's code and its documentation are
GPL-3.0-or-later. The upstream MIT notice and its conditions still apply to the
upstream material.

Earlier versions used a different base and several comparison tables. The
current table matches the askbuddie pin except for the values listed below, so
anyone can rebuild it from that base. This file records the current reference.
It does not claim that earlier work was created independently, or that a change
of reference settles every provenance question. Git history holds the earlier
source decisions.

## Retained historical corrections

On 3 October 2026 the maintainer decided to keep these values. In each cell,
the months appear in the order of the "Affected months" column. Every other
value from 1975 to 2083 matches askbuddie exactly.

| Year | Affected months | NepalKit | askbuddie | Evidence status |
| --- | --- | --- | --- | --- |
| 1989 | Kartik, Mangsir | 30, 29 | 29, 30 | Dharan converter checked on 3 October 2026. Boundaries below. |
| 1993 | Ashar, Shrawan | 31, 32 | 32, 31 | Dharan converter checked on 3 October 2026. Boundaries below. |
| 2004 | Poush, Magh | 29, 30 | 30, 29 | Kept by decision. The earlier reason for the choice could not be recovered. |
| 2082 | Ashoj, Mangsir, Poush, Magh | 31, 29, 30, 29 | 30, 30, 29, 30 | Test fixture: Magh 20 maps to 3 February 2026, attributed to a Nepali Patro converter. |
| 2083 | Ashoj, Mangsir, Poush, Magh | 31, 29, 30, 29 | 30, 30, 29, 30 | Official 2083 Panchanga, all twelve months (below). An earlier check of the Kathmandu Metropolitan City calendar also gave Ashoj 31 days. |

### Official Panchanga check for 2083

The Nepal Panchanga Nirnayak Samiti, under the Ministry of Culture, Tourism and
Civil Aviation, publishes the government's national Panchanga. Its 2083 BS
edition confirms all twelve 2083 month lengths, including the four corrected
months above.

- Page: [npns.gov.np, Panchanga of the year 2083](https://npns.gov.np/pages/panchanga-of-the-year-2083-5/).
- File read: [`FORMAT-2083-A_7f75xmb.pdf`](https://giwmscdnone.gov.np/media/pages/files/FORMAT-2083-A_7f75xmb.pdf),
  27 pages, image only (no text layer), SHA-256
  `e7615a149018edd41e6239f7d0ed0c513f94e0566277dca7af41347c62713bde`.
- Read by eye on 11 October 2026 from the day (गते) and weekday (वार) columns
  at each month boundary on pages 3 to 27. The maintainer copied no data from
  it into NepalKit.

| 2083 month | Baisakh | Jestha | Ashar | Shrawan | Bhadra | Ashoj | Kartik | Mangsir | Poush | Magh | Falgun | Chaitra |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Panchanga | 31 | 31 | 32 | 31 | 31 | 31 | 30 | 29 | 30 | 29 | 30 | 30 |
| NepalKit | 31 | 31 | 32 | 31 | 31 | 31 | 30 | 29 | 30 | 29 | 30 | 30 |

The printed weekdays agree with NepalKit's Gregorian anchor. The Panchanga gives
1 Baisakh 2083 as a Tuesday (14 April 2026), 1 Kartik as a Sunday (18 October
2026, the Gregorian date it also prints), and 1 Baisakh 2084 as a Wednesday
(14 April 2027). This is the first official source for 2083 that the project
has recorded. The 2084 row stays a projection until the 2084 Panchanga is
published.

### Festivals and national days

Festivals and national days come only from the year's national Panchanga,
except two national days that only the gazette notice dates (see the next
paragraph). NepalKit takes no festival dates from any other calendar, website,
or app. A
year gets festivals only after its Panchanga is published, so the provisional
2084 row has none.

The selection rule takes Nepal's national days and the once-a-year festivals
observed across Nepal or by a large community, such as New Year, Buddha
Jayanti, Teej, Dashain, Tihar, Chhath, Lhosar, and Holi. It leaves out
fortnightly and monthly observances (Ekadashi, Pradosh, monthly Purnima, Aunsi,
and Sankranti), local jatras, international days, and timing notes. An
international day that the gazette notice makes a holiday still gets a name,
as the next paragraph says. The rule ignores the Panchanga's bold type. The
Panchanga prints प्रदोषव्रत in bold and the New Year in regular type.

For 2083 the maintainer typed in every day's observances from the PDF pinned
above, and 57 passed the selection rule. A second, independent read of the page
images confirmed each one's day and wording, including three that the
Panchanga prints as overflow in another day's row. Each holiday or national day
in the gazette notice below also gets a name, so no red day is unnamed. That
brings the list to 67 entries. Their wording is the Panchanga's, with the outer
brackets dropped, wherever the Panchanga prints the day. The two days it does
not print, जेनजी सहिद दिवस and ज्यापू दिवस, take the gazette's wording and
carry `source: .gazette`. The data is in
[`Festivals2083.swift`](NepalKitCore/Sources/NepalKitCore/Festivals2083.swift).

### Public holidays

The Ministry of Home Affairs notice for the year in the Nepal Gazette decides
which days are public holidays and for whom. The app says "public holiday" only
where the gazette notice does. The month grid shows only nationwide holidays in
red. The day's details name the holidays with a narrower scope. For 2083 the
gazette notice is खण्ड ७५ संख्या ६७, भाग ५, dated 2082-11-18:

- File read: [`२०८३_सालको_सार्वजनिक_विदा_(67_11_18).pdf`](https://moha.gov.np/upload/e66443e81e8cc9c4fa5c099a1fb1bb87/files/%E0%A5%A8%E0%A5%A6%E0%A5%AE%E0%A5%A9_%E0%A4%B8%E0%A4%BE%E0%A4%B2%E0%A4%95%E0%A5%8B_%E0%A4%B8%E0%A4%BE%E0%A4%B0%E0%A5%8D%E0%A4%B5%E0%A4%9C%E0%A4%A8%E0%A4%BF%E0%A4%95_%E0%A4%B5%E0%A4%BF%E0%A4%A6%E0%A4%BE_(67_11_18).pdf),
  12 pages, image only, SHA-256 `ffbabf83cad254b485504627f9e47fce6c1a7a28e2693a399ae88bf9c0279a29`.
- Read by eye on 11 October 2026: 47 holiday rows on 41 days, each with its
  gazette section and scope, plus three national days on which offices stay
  open. A second, independent read of the page images confirmed every date,
  section, scope, and printed weekday, the Dashain (Ashoj 31 to Kartik 6) and
  Tihar (Kartik 22 to 26) ranges, and the 52 Saturdays of section 1.
- Every dated holiday falls on the day the Panchanga gives. Two national days
  that the Panchanga does not print, ज्यापू दिवस and जेनजी सहिद दिवस, take the
  gazette notice as their source.
- The gazette notice lists some holidays "on the day" with no date: both Eids,
  Mohammad Jayanti, Siruwa Pawani, Bhoto Jatra, and Guru Nanak Jayanti.
  NepalKit leaves them out, except Guru Nanak Jayanti, which takes the
  Panchanga's date.
- Holidays that a province declares are not in this notice.

The data is in
[`PublicHolidays2083.swift`](NepalKitCore/Sources/NepalKitCore/PublicHolidays2083.swift).

### Dharan converter checks

The verification reference is the [Dharan e-BPS converter](https://ebps.dharan.gov.np/Hom/Converter).
On 3 October 2026 the page's `ConvertToEnglish` function returned the results
below. It takes year-month-day and returns month, day, and year in that order.
The table shows both as year-month-day. NepalKit copies no converter code and
no complete municipal dataset.

| Bikram Sambat input | Gregorian result |
| --- | --- |
| 1989-07-01 | 1932-10-17 |
| 1989-07-30 | 1932-11-15 |
| 1989-08-01 | 1932-11-16 |
| 1989-08-29 | 1932-12-14 |
| 1989-09-01 | 1932-12-15 |
| 1993-03-01 | 1936-06-14 |
| 1993-03-31 | 1936-07-14 |
| 1993-04-01 | 1936-07-15 |
| 1993-04-32 | 1936-08-15 |
| 1993-05-01 | 1936-08-16 |

The gaps between consecutive month starts show that in 1989 Kartik has 30 days
and Mangsir 29, and that in 1993 Ashar has 31 days and Shrawan 32. These are converter
results, not official records. Benchmark years supplied earlier (1982, 1986,
and 1998 Gregorian) did not match the Bikram Sambat years they were given for,
so NepalKit does not use them.

## NepalKit's 2084 projection

The maintainer's provisional row for 2084 is:

`[31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30]`

It totals 365 days. It places Bhadra 22 on 8 September 2027, as a reported
birthday requires, and gives Chaitra 30 days. It is not a transcription of an
officially approved Nepali Patro or the result of a verified astronomical
calculation. NepalKit claims no general rule, such as a four-year cycle, for
projecting years.

The row differs from askbuddie's 2084 row in Jestha, Ashar, Shrawan, and Magh.
`Projected2084Tests` checks the provisional row, including Bhadra 22 mapping to
8 September 2027. These tests show that the code matches the row, not that the
row is accurate.

## Reproduce the comparison

```sh
python3 scripts/verify-data-sources.py --baseline scripts/data-sources-baseline.json
python3 scripts/verify-data-sources.py --offline --baseline scripts/data-sources-baseline.json
```

The script fetches only askbuddie. Across the 110 years of the supported range
and their 1,320 month values, 104 years match exactly. Eighteen months differ:
the 14 retained historical corrections and four months of the 2084 projection.
The baseline records these exceptions. A passing run means the recorded
comparison still holds, not that every month is independently verified.
`--offline` reads the copy that an earlier fetch cached in
`~/.cache/nepalkit-data-sources/`.

Review a change to month lengths, the source pin, or the exception decisions
together with the baseline update that it causes:

```sh
python3 scripts/verify-data-sources.py --update-baseline
```

For a candidate year, `scripts/verify-candidate-year.py` reports the pinned
base's row. The base's rows past 2084 do not extend NepalKit's supported range.
To extend it, follow [Updating the calendar data](docs/updating-calendar-data.md).

## Copyright scope

Nepal's Copyright Act treats general factual data differently from original
compilations and from works the government creates. This project does not
claim that every source publication or whole dataset is in the public domain,
or that a new schema alone proves independent creation. NepalKit keeps the MIT
grant and notice for the base, documents its own factual decisions and the
projection, and assesses any new source or wholesale import separately. The
evidence for the exceptions is a verification reference, not permission to
redistribute the source publications.
