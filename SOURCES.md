# Calendar data: sources, licences, and how the table was decided

NepalKit converts Bikram Sambat dates with a static, table-driven engine. There
is no closed-form rule for Bikram Sambat month lengths, so the table *is* the
product's correctness core. This document says where it came from, under what
terms, and where a reader should be sceptical.

It is written to be checkable. Every claim here can be re-run with
`python3 scripts/verify-data-sources.py`.

## The honest summary

**The shipped table is not independently licensed, and this document does not
claim it is.** It is derived from one base source across its entire range. A
second, cleanly-licensed source corroborates most of it month-by-month. Where
the two disagree, a third table and published Nepali calendar material decided
each case individually, and the decision is recorded below.

The base source is a fork. Its upstream **carries no licence file at all**, and
the fork later added one for itself. A licence granted by someone who may not
have held the underlying rights is not the same as a clean grant, and a reader
who checks the upstream will find exactly that. The upstream permission request
is tracked as a separate, external piece of work and is not resolved by
anything written here.

The 2.0.0 range narrowing (ADR-0010) removed the years that had no corroboration
at all. That reduced the exposure. **It did not make the remaining table
independently licensed**, and no documentation here should be read as saying so.

## Sources

Every entry is pinned to an immutable commit. Branches are not used, because
licences get changed silently and the base source's own history contains exactly
that — a fork that adopted a licence its upstream never had.

### 1. Base table — `medic/bikram-sambat`

| | |
| --- | --- |
| Repository | <https://github.com/medic/bikram-sambat> |
| Pinned commit | `aeaa7b88332384bddeea98c2445308d437966641` (2026-09-16) |
| Data file | `test-data/daysInMonth.json` |
| Range published | 1970–2090 BS |
| Licence | Apache-2.0, added 2018-09-18 in `8efb35d46e1c` |
| Copyright holder | not stated in the repository |
| Role | **base table** — the source of the shipped month lengths |

This is a **fork** of `alxndrsn/bikram-sambat.js`, pinned at
`ed476271561c…` (2017-06-02), which **has no licence file**. Under default
copyright that means all rights reserved. The fork's Apache-2.0 grant therefore
cannot be traced back to a clean grant for the rows it inherited, and the
provenance chain does not terminate in one. This is the load-bearing problem
with the dataset, and it is why an upstream permission request exists.

NepalKit ships 1975–2084 of the 121 years this table publishes. Rows for 2085
and beyond are deliberately **not** shipped: 2085 is not officially published,
and "the source has it" is not a reason to widen the conversion contract
(ADR-0001).

### 2. Corroboration — `askbuddie/bikram-sambat`

| | |
| --- | --- |
| Repository | <https://github.com/askbuddie/bikram-sambat> |
| Pinned commit | `d3475606084141352d3bf4472c80f9051968551a` (2025-01-23) |
| Data file | `src/data/days-in-month-mapping.ts` |
| Range published | **1975–2100 BS** |
| Licence | **MIT** |
| Copyright holder | not stated in the repository |
| Role | **corroboration** — an independent check, not a source of any value |

This is the one cleanly-licensed source in the project. It is a corroboration
and not a source: at every disputed month below, the shipped value did **not**
come from here.

Its range starts at **1975**, which is the whole explanation for the 2.0.0
narrowing. The years 1970–1974 were not single-source because of a judgement
about their quality; they were single-source because the corroborating table
**does not contain them**, so no second opinion was available for those five
years at any point. Cutting them removed the only years that had never been
checked against anything.

### 3. Third table — python, unavailable

A third table, in python, was used to break ties by majority vote. **It is not
available**, so the comparison cannot be reproduced and its values cannot be
re-examined. Recorded as a gap rather than described as though it were still
checkable.

### 4. Arbitration material — published Nepali calendars

Used only where the two tables above disagreed, to decide which value was right.
These are **sources of evidence for an arbitration**, not sources of any shipped
value.

| Source | Status as of 28 September 2026 |
| --- | --- |
| KMC government calendar grids | cited in tests; grid not re-verifiable from here |
| Hamro Patro | cited in tests; site unreachable |
| Nepali Patro converter | cited in tests; not re-verifiable from here |
| mypatro | cited in tests; **unreachable** |
| ashesh 1970–2100 grids | cited in tests; not re-verifiable from here |
| rat32 | cited in tests; not re-verifiable from here |
| khudra | cited in tests; **unreachable** |
| nepali-calendar.com | cited in tests; **unreachable** |

None of these is permissively licensed, and several are unreachable. They are
listed as a **historical cross-check only**. None is a current source, and none
should be treated as one. A reader cannot re-run this stage of the work; that is
stated here rather than left for them to discover.

## The cross-check, and how to re-run it

Month lengths were compared year by year across the 110 shipped years, 1320 month
values in total, against both community tables. Running:

```sh
python3 scripts/verify-data-sources.py
```

reproduces the comparison against the pinned commits. Current result:

- **against `medic`: 107 of 110 years match exactly**, 6 months differ
- **against `askbuddie`: 105 of 110 years match exactly**, 14 months differ

The two tables disagree with each other on 22 month values across the full
1975–2090 overlap; 20 of those fall inside the shipped range. Every shipped year
except the eight below matches both sources exactly.

**A correction was absorbed after the original transcription.** `medic` corrected
its own rows for 2081 and 2082 (PR #27, merged 2025-03-14) and for 2083
(commit `2bb4363b807e`, 2026-06-04). The shipped rows match the corrected
values, and a 2081 regression is *not* caught by the suite — see ADR-0010, which
records that 8 of 110 years have any month-boundary assertion. Anyone
re-transcribing must work from a checkout at or after `aeaa7b883323`, and must
use the command above rather than trusting a branch.

## The disputed months, and which side was taken

Twenty months across eight shipped years. No third or fourth year of
disagreement is outstanding.

| Year | Months | Shipped value follows | Decided by |
| --- | --- | --- | --- |
| 1975 | Bhadra, Ashwin | `askbuddie` | ashesh Bhadra/Ashwin pair, Navami→Dwadashi tithi continuity |
| 1989 | Kartik, Mangsir | `medic` | ashesh self-consistent pair (Kartik 30 = 15 Nov, Mangsir 1 = 16 Nov) |
| 1991 | Mangsir, Poush | `askbuddie` | ashesh Mangsir 1991 = 30 days |
| 1993 | Ashar, Shrawan | `medic` | ashesh Ashar grid, 31 days ending 14 July |
| **2004** | **Poush, Magh** | **`medic`** | **not itemised in the earlier record — see below** |
| 2062 | Baisakh, Jestha | `askbuddie` | ashesh Baisakh/Jestha 2062 = 31/31, tithi-continuous |
| 2082 | Ashwin, Mangsir, Poush, Magh | `medic` | Nepali Patro converter, Magh 20 ↔ 3 Feb 2026 |
| 2083 | Ashwin, Mangsir, Poush, Magh | `medic` | KMC government grid, 31-day Ashoj |

### One gap in the earlier record

The v1 work recorded nine ties broken by majority vote and itemised seven of
them by year. **2004 (Poush, Magh) was not itemised**, and the shipped table
follows `medic` there. The count of nine is right — it is nine *years* in which
the sources disagree, not nine months — but 2004's resolution is not written
down anywhere in the repository's history. The shipped values are asserted here
and covered by `ArbitratedDisputeTests`, but the evidence for *why* `medic` was
followed at 2004 is not recoverable from what was written down. Flagged rather
than reconstructed.

The earlier record also cites 2084 among the published-calendar confirmations.
`medic` and `askbuddie` **agree** on 2084, so it was never a dispute between the
two community tables; the confirmation there was corroboration of a value both
already held.

## Why 2084 is the upper bound

2084 BS is the most recent officially published Nepali calendar year. 2085 and
beyond are not published, and nothing is extrapolated: a projected year would be
a guess presented as data (ADR-0001). `medic` does publish rows past 2084, and
they are deliberately not shipped.

## What is not a licence

Two arguments that sound protective and are not, recorded because they will
otherwise be offered:

**"It comes from the official Nepali Patro."** The publisher of an official
calendar holds rights in it under its own jurisdiction's copyright law, and may
license or sell them. The equivalent United States provision covers only that
government's own works. This project is not a United States government work.

**"It's just facts."** A few thousand month lengths are facts with essentially
no creative expression, and there is no practical enforcement against comparable
applications. Both of those are probably true. Neither is a licence, and
neither is a defence that has ever been tested.

What actually protects this table is the first point above plus the third: few
facts, little expression, no enforcement. That is a description of why
enforcement has not been pursued, not a grant of permission.
