# Calendar data sources and licences

NepalKit's dataset 2.0.1 supports 1975–2084 Bikram Sambat. Its current reference
is one pinned base table, with explicit NepalKit corrections and a local 2084
projection. Conversion remains offline. This source cleanup changes no month
length, Gregorian anchor, supported range or dataset version.

## Base reference

- Repository: [askbuddie/bikram-sambat](https://github.com/askbuddie/bikram-sambat).
- Requested file: [days-in-month-mapping.ts](https://github.com/askbuddie/bikram-sambat/blob/main/src/data/days-in-month-mapping.ts).
- Reproducible pin: [`d3475606084141352d3bf4472c80f9051968551a`](https://github.com/askbuddie/bikram-sambat/blob/d3475606084141352d3bf4472c80f9051968551a/src/data/days-in-month-mapping.ts).
- Source coverage: 1975–2100; NepalKit uses 1975–2083 as its historical base.
- Licence: [MIT](https://github.com/askbuddie/bikram-sambat/blob/d3475606084141352d3bf4472c80f9051968551a/LICENSE), copyright (c) 2023 Ask Buddie.

The complete upstream notice is retained in
[AskBuddie-LICENSE.txt](NepalKitCore/Sources/NepalKitCore/Resources/AskBuddie-LICENSE.txt).
SwiftPM copies it into the shared core resource bundle for app distributions.
NepalKit's code and documentation remain GPL-3.0-or-later; the upstream MIT
notice and permission conditions remain applicable to upstream material.

Earlier versions used a different base and several comparison tables. The
current table has been checked against the askbuddie pin and can be reproduced
from that base with exactly the exceptions below. This records the current
reference, not a claim that earlier work was independently created or that
changing references alone resolves every provenance question. Historical
source decisions remain in git history and superseded ADRs.

## Retained historical corrections

On 3 October 2026 the maintainer explicitly retained these values. Month order
in each cell follows the affected-month column. All other historical values
match askbuddie exactly.

| Year | Affected months | NepalKit | askbuddie | Evidence status |
| --- | --- | --- | --- | --- |
| 1989 | Kartik, Mangsir | 30, 29 | 29, 30 | Dharan converter checked on 3 October 2026; boundaries below |
| 1993 | Ashar, Shrawan | 31, 32 | 32, 31 | Dharan converter checked on 3 October 2026; boundaries below |
| 2004 | Poush, Magh | 29, 30 | 30, 29 | Retained decision; previous arbitration rationale was not recoverable |
| 2082 | Ashwin, Mangsir, Poush, Magh | 31, 29, 30, 29 | 30, 30, 29, 30 | Existing fixture: Magh 20 maps to 3 February 2026, attributed to Nepali Patro converter |
| 2083 | Ashwin, Mangsir, Poush, Magh | 31, 29, 30, 29 | 30, 30, 29, 30 | Existing KMC grid check: Ashwin has 31 days |

The 2082 and 2083 descriptions preserve earlier evidence; those sources were
not freshly checked during this cleanup. A maintainer-supplied claim of
Parliamentary Portal or MOHA Gazette verification has no exact record or decree
attached here and is not presented as independently verified. A single date
fixture also does not verify every corrected month in its year.

The one-time amitgaru CSV comparison requested during this cleanup matched the
retained 2004, 2082 and 2083 rows. It is corroboration, not an additional base or
an automated source dependency. The pinned comparison is recorded in
[the cleanup evidence](docs/release-evidence/dataset-source-cleanup.md).

### Dharan converter checks

Verification reference: [Dharan e-BPS converter](https://ebps.dharan.gov.np/Hom/Converter).
The page's loaded `ConvertToEnglish` function returned these results on
3 October 2026. Its input uses year-month-day; the output uses month/day/year.
No converter implementation or complete municipal dataset is copied into
NepalKit.

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

The consecutive month-start intervals corroborate Kartik/Mangsir 1989 as 30/29
and Ashar/Shrawan 1993 as 31/32. These are converter observations, not Gazette
attestations. The earlier supplied benchmark years 1982, 1986 and 1998 Gregorian
were inconsistent with the named Bikram Sambat years and are not used.

## NepalKit's 2084 projection

The maintainer's provisional row is:

`[31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30]`

It totals 365 days and remains unchanged. It follows the reported birthday and
Chaitra recurrence; it is not a transcription of an officially approved Nepali
Patro or the result of a verified astronomical calculation. No general
four-year extrapolation rule is claimed.

Relative to askbuddie's 2084 row, Jestha, Ashar, Shrawan and Magh differ.
Projected2084Tests asserts this provisional contract, including Bhadra 22 mapping
to 8 September 2027. These tests establish implementation consistency, not
independent accuracy. The supported Gregorian interval remains 1918-04-13
through 2028-04-12.

The projection is retained for development/testing pending official-calendar
comparison. This cleanup does not authorize public distribution or clear the
Watch acceptance blocker. See [the original projection decision](docs/watch/provisional-2084-update.md)
and [ADR-0014](docs/adr/0014-calendar-base-and-local-exceptions.md).

## Reproduce the comparison

```sh
python3 scripts/verify-data-sources.py --baseline scripts/data-sources-baseline.json
python3 scripts/verify-data-sources.py --offline --baseline scripts/data-sources-baseline.json
```

Only askbuddie is fetched. Across 110 supported years and 1,320 month values,
104 years match exactly; 18 months differ: the 14 retained historical values
and four values in the local 2084 projection. The baseline records these
exceptions. A green result means the recorded comparison holds, not that every
month is independently verified. Offline mode requires a prior cached fetch.

A change to month lengths, the source pin or the exception decisions must be
reviewed with the corresponding baseline update:

```sh
python3 scripts/verify-data-sources.py --update-baseline
```

For a future candidate, `scripts/verify-candidate-year.py` reports the same
pinned base's row. Source coverage beyond 2084 does not expand NepalKit's
supported range automatically. Follow [the update procedure](docs/release-evidence/dataset-extension-procedure.md).

## Copyright scope

Nepal's Copyright Act distinguishes general factual data from original
compilations and government-created works. This project does not claim that
all source publications or entire datasets are public domain, or that a new
schema alone proves independent creation. We retain the MIT grant and notice
for the base, document local factual decisions and the projection, and assess
any new source or wholesale import separately. The exception evidence is a
verification reference, not permission to redistribute source publications.
