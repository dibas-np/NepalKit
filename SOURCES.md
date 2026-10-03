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

Two further tables are now recorded as corroboration, `SuprimKhatri77/go-bs` and
`subeshb1/Nepali-Date`. Neither is a fork, and both are MIT, so the licence
picture is better than it was — but **neither can be the base table**: `go-bs`
does not cover 1975–1978, and `subeshb1` does not cover 1975–1999. The base is
still `medic`, and nothing here changes that.

`subeshb1` did more than add a fourth opinion. **It exposed that the shipped 2084
row is projected rather than published**, correcting a false claim this document
previously made, and it initially contested that year by a day. The Kathmandu
Metropolitan City calendar then settled it: it reproduces 2083 exactly and gives
2084 identically to the shipped table, making the split three sources to one.
**That earlier dataset 2.0.0 decision is superseded for 2084 by the provisional
2.0.1 decision below.** See "Why 2084 is the upper bound". It is
**MIT and not a fork**, so it is the best-licensed of the three and has no
unlicensed ancestor — but it cannot be the base table (it does not cover
1975–1978), and its own documentation records that its 2000–2100 rows were
scraped from a private commercial calendar service. It improves the licence
picture and leaves the provenance question where it was. **No entry in this
document has been removed on the strength of it**, because the shipped table
still derives from the base source and saying otherwise would make this file
false.

## Current provisional 2084 decision (dataset 2.0.1)

On 3 October 2026, the user explicitly selected this temporary development/testing
projection pending comparison with the official 2084 Nepali Patro:

`[31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30]`

It totals 365 days. Relative to dataset 2.0.0, Jestha changes 31 → 32,
Ashar 32 → 31, Shrawan 31 → 32, and Magh 30 → 29. Bhadra 22 now maps
to 8 September 2027 using the existing year-start anchor; Chaitra remains
30 days. The Gregorian supported interval remains 1918-04-13 through
2028-04-12. Both Mac and Watch use this one shared compiled table. The dataset
version is bumped to 2.0.1; the public major-version symbol remains v2.

This is a user-approved candidate based on the reported birthday recurrence
and Chaitra pattern, not a transcription of an officially approved calendar,
not an output of a verified Drik calculation, and not a majority-source result.
It differs from the earlier KMC/medic/askbuddie projection and also differs from
the 366-day subeshb1 row, whose Chaitra has 31 days. Historical source comparisons
below describe dataset 2.0.0 unless explicitly stated otherwise.

2084 remains provisional development/testing data and does not satisfy
ADR-0001. This change does not authorize public distribution, amend that policy
or clear the Watch final-feature-acceptance blocker. When the official 2084
Patro becomes available, compare all twelve month lengths and independently
check New Year/month-start boundaries, record provenance, revise values as
needed and version the shared dataset again. Do not assume the temporary row
will match or impose a four-year extrapolation rule on future years.

The 2084 regression fixtures now explicitly test this provisional decision in
Projected2084Tests, rather than presenting it as external attestation in the
published-calendar/arbitration suites. Historical anchored fixtures remain.
The regenerated pinned-source baseline records 39 comparison pairs over 25
unique months. All non-2084 differences are unchanged; the current row differs
in four months from each of medic/askbuddie/go-bs and only Chaitra from
subeshb1. The baseline records these changed differences honestly; a green comparison means the recorded observation holds,
not that the projection is correct.

## The licence covers the code, not this table

The repository is GPL-3.0-or-later (see `LICENSE`).

**That grant covers the code and this document. It does not extend to the
calendar table**, and copyleft makes the boundary more important to state, not
less: a reader may reasonably assume a single strong copyleft grant covers the
whole repository, data files included. It does not.

GPL was chosen partly *because* of the table. `medic/bikram-sambat` is
Apache-2.0, and Apache-2.0 is one-way compatible with GPLv3, so GPL is the
licence under which that material can lawfully travel with the code. That solves
compatibility. It does not solve provenance: the fork's parent,
`alxndrsn/bikram-sambat.js`, carries no licence at all, and no downstream choice
of licence manufactures a grant that was never given.

If the table is re-derived from sources carrying unambiguous licences, this
caveat can be removed. Until then it stands.

## Sources

Every entry is pinned to an immutable commit. Branches are not used, because
licences get changed silently and the base source's own history contains exactly
that — a fork that adopted a licence its upstream never had.

The licence status of every source was re-checked against the GitHub API while
writing this, rather than trusted from the earlier pass. Both claims held:
`medic/bikram-sambat` reports `Apache-2.0` and is a fork, while its parent
`alxndrsn/bikram-sambat.js` reports **no licence at all** (`"license": null`).
`askbuddie/bikram-sambat` reports `MIT` and is not a fork.

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

### 3. Additional sources consulted

Two further MIT-licensed tables were checked and are recorded compactly, because
neither changed a shipped value. They are listed so a reader knows what was
consulted — **not** as support for any row.

| | `SuprimKhatri77/go-bs` | `subeshb1/Nepali-Date` |
| --- | --- | --- |
| Pinned commit | `5853e0e91482d8bb6f400da4f69138fbe69a85dc` | `2183c30ada24a7fe678a24d58a5aa61ce8cdfa85` |
| Data file | `data.go` | `src/date-config.ts` |
| Licence | MIT | MIT — holder named (Subesh Bhandari) |
| Fork | no | no |
| Established | 2026 | 2018; 66 stars, 30 forks, on npm |
| Range | 1979–2100 | 2000–2090 |
| Shipped years it cannot cover | 1975–1978 | **1975–1999** |
| Overlapping years | 106 | 85 |
| Years matching exactly | **104 / 106** | **83 / 85** |
| Provenance stated | none | none |
| Impossible year totals in its own table | 2087 (367d), 2096 (364d) | none |

Neither is a fork, so both are free of the unlicensed upstream that burdens the
base table, and both are re-checkable with
`python3 scripts/verify-data-sources.py`. Neither could have been the base: each
is missing shipped years, and together they still miss 1975–1999.

**Two disagreements, both recorded because both were real.**

- **`subeshb1` on 2062** (Baisakh, Jestha) — it sides with `medic`, where this
  project followed `askbuddie` on the recorded tithi-continuity grounds. A
  transposition: both years total 365. Noted against that arbitration; the year
  is attested and the decision stands.
- **`subeshb1` on 2084** — five months, **and a different year total** (366
  against 365). This was the disagreement that prompted the check below, and it
  is recorded because a resolved dispute is part of the record. `subeshb1` is
  the outlier; the shipped row is retained.

`go-bs` also disagreed on 1989 (Kartik/Mangsir) and 1993 (Ashadh/Shrawan), both
transpositions, both inside the 1979–1999 band its own documentation flags as
never checked against a live source. Not recorded individually: neither year
moved a year boundary, and no source with a live record contradicts them.

### 4. Adjudication — Kathmandu Metropolitan City calendar

| | |
| --- | --- |
| Source | <https://kathmandu.gov.np/en/calendar?view=bs> |
| Publisher | Kathmandu Metropolitan City (municipal government body) |
| Licence | **none stated** — not open data |
| `robots.txt` | `Allow: /`; the calendar path is not disallowed |
| Range published | **2083–2085 BS only** |
| Role | **adjudication** — used to settle 2084, not a source of any shipped value |

Added because it is a government body's republication of the national calendar,
which is closer to authority than any community table. It is also the only source
consulted here that publishes a **future** BS year.

**It cannot be a source for the shipped range.** Three years is 3 of 110. It
cannot be the base table, cannot replace `medic`, and cannot corroborate anything
before 2083. Its entire value was in one year.

**Structure.** The calendar is rendered into a Next.js RSC payload rather than as
server-side HTML, carrying per-day `bs_year` / `bs_month` / `bs_day` / `ad_date`
records and public holidays in both English and Nepali. Month lengths are derived
by counting distinct `bs_day` values per month — deliberately counting rather than
trusting row totals, so a partially-rendered month cannot be mistaken for a short
one.

**It is checked by a separate script, not by `verify-data-sources.py`.** That
script compares pinned immutable files so its results never change. This source
is a live website: results can change, the site can go down, and each year costs
twelve requests. Run it deliberately:

```sh
scripts/check-kathmandu-calendar.py 2083 2084 2085
```

**Historical results against dataset 2.0.0:** 2083 matched exactly. 2084
matched that former projection exactly. The current 2.0.1 projection deliberately
differs; that historical match does not describe it. 2085 is not shipped.

**Licensing and permission remain unresolved, and are not asserted away.** No open
licence is offered. `robots.txt` permitting crawling is not permission to
redistribute, and the Samiti's requirement that a published calendar carry its
approval (see "What is not a licence") is untouched by any of this. KMC is
recorded as an adjudication reference, not as a licensed source, and nothing from
it is vendored into the repository.

### 5. Third table — python, unavailable

A third table, in python, was used to break ties by majority vote. **It is not
available**, so the comparison cannot be reproduced and its values cannot be
re-examined. Recorded as a gap rather than described as though it were still
checkable.

### 6. Arbitration material — published Nepali calendars

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

Four sources are compared by `verify-data-sources.py`: `medic` (base),
`askbuddie`, `go-bs` and `subeshb1/Nepali-Date`.

**The two compactly-recorded tables stay in the script even though neither
changed a shipped value.** The script is the evidence; this document is the
summary. Dropping a source from the comparison would mean the numbers quoted
here could no longer be re-derived, and a reader checking this file would find
claims with nothing behind them. Removing them from the *narrative* is fair —
removing them from the *evidence* is not.

The script reports, per source, which shipped years it **cannot** cover — 25 for
`subeshb1`, 4 for `go-bs` — because a source that silently skips years looks
more complete than it is.

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

## Why 2084 is the upper bound — and a correction

**An earlier version of this document said 2084 BS was "the most recent
officially published Nepali calendar year". That was wrong.** It is not published.

The Nepal Panchanga Nirnayak Samiti approves each year's patro a few months
before that year begins, and **it has published through 2083 BS only**. Its own
publication notices on `npns.gov.np` are for 2082 and 2083; the 2083 almanac was
confirmed published in December 2025 following the same pattern as 2082. The
official determination of **2084 is expected around Magh 2083 BS
(January–February 2027)** — which had not happened as of 28 September 2026, when
this was checked.

So the honest position is:

| Years | Evidence |
| --- | --- |
| 1975–2083 | multiple independent sources, all deriving from an **already-published** Panchanga |
| **2084** | **projected.** No official patro exists yet |

**This means the shipped 2084 row is a projection presented in a table of
otherwise-attested data, which is in tension with ADR-0001's rule that nothing
is extrapolated.** It is recorded here rather than smoothed over, and the
range decision that follows from it is ADR-0010's to revisit, not this
document's to make silently.

**2085 and beyond are excluded outright.** `medic` does publish rows past 2084,
and they are deliberately not shipped.

### Historical 2084 arbitration, superseded by dataset 2.0.1

`subeshb1/Nepali-Date` (section 3) disagreed with the shipped 2084 row in five
months, **and on the year total**:

| | Shipped | `subeshb1/Nepali-Date` |
| --- | --- | --- |
| Jestha | 31 | 32 |
| Ashadh | 32 | 31 |
| Shrawan | 31 | 32 |
| Magh | 30 | 29 |
| Chaitra | 30 | 31 |
| **Year total** | **365** | **366** |

Every other disagreement in this document is a transposition between adjacent
months that leaves the year total alone. **This one does not** — the two tables
place Baisakh 1 2085 a day apart, so it moves real dates for anyone in the
second half of 2084.

The shipped row is corroborated by `medic` and `askbuddie`; `subeshb1` is alone.
Neither side has official attestation, because none exists. The shipped row also
ends in a `(30, 30, 30)` tail, which is the signature that distinguishes
projected rows from published ones elsewhere in this ecosystem.

**Resolved by the government calendar — the shipped row stands.**
`subeshb1` is the outlier. The Kathmandu Metropolitan City calendar
(section 4) gives 2084 as `[31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30]`,
365 days — **identical to the shipped table, including the `(30, 30, 30)` tail**
— and it reproduces 2083 exactly as well, so it is a reliable reader rather than
a source that happens to agree. That makes the split **three sources to one**:

| Source | 2084 | Licence |
| --- | --- | --- |
| `medic` (base) | 365 — matches shipped | Apache-2.0, unlicensed upstream |
| `askbuddie` | 365 — matches shipped | MIT |
| Kathmandu Metropolitan City | 365 — matches shipped | none stated |
| `subeshb1/Nepali-Date` | **366** | MIT |

That investigation retained the dataset 2.0.0 values at the time. The
provisional 2.0.1 decision above subsequently changes four months.

**What this does not establish.** A match is corroboration of the *values*, not
proof of *official attestation*. KMC republishes the national calendar, but
showing a future BS year is also exactly what a projection does — and 2084 does
not begin until April 2027, so the site is showing it roughly seven months
ahead. Only the Samiti can attest a year. The table above stands as corrected:
**The former 2084 row was projected, not attested**, with three sources
corroborating that projection. This does not corroborate the revised 2.0.1 row.

For the future, KMC's 2085 is `[31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30]`
(366 days), which matches the Hamro Patro / `nepali-datetime` pair independently
reported as agreeing on that year. Still not shipped: nothing is extrapolated
(ADR-0001), and agreement between projections is not attestation.

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
