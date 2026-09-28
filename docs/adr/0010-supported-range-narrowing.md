# The supported range narrows on lost corroboration, not only on new data

**Refines ADR-0001. Applies the versioning separation in ADR-0009.**

ADR-0001 decided that the bundled table holds only verified calendar data, that
nothing is extrapolated, and that its supported range "expands only when new
official Patro data becomes available." The cross-check behind that table found
that the years 1970–1974 were corroborated by no second table: they are the only
years in the range resting on the base source alone. Dataset 1.0.0 shipped them
anyway.

This records narrowing them, and generalises the rule: **the supported range
narrows when the shipped table can no longer be corroborated for part of it, as
well as extending when new Patro data is published.** A range is a statement
about how well the data is supported, so it has to be able to move in the
downward direction. Dataset 2.0.0 ships 1975–2084 BS.

Narrowing the range is a breaking change to the public conversion contract, so
the dataset version takes a major bump, `1.0.0` → `2.0.0`. That the dataset
version moves independently of the application version is ADR-0009's rule, not
ADR-0002's — ADR-0002 records the update *strategy* and says nothing about
version numbers. ADR-0002's "may bundle an expanded dataset" is the half of the
rule that survives here; this record is the other half.

The bundled static is renamed `CalendarDataset.v1` → `CalendarDataset.v2` to
match. The identifier is public API of the core package, and leaving a symbol
named `v1` that declares `"2.0.0"` would be a name that lies about the contract
it names. The rename is the reason this change touches four app sources and
eight test files, and that cost is accepted rather than worked around by leaving
the old name pointing at a different range.

The Gregorian lower bound is not a separate setting. It follows from the table:
1 Baisakh 1975 is 13 April 1918, so the convertible span starts at 1918-04-13
rather than 1913-04-13. `ConverterModel` derives both ends by converting the
first and last days of `supportedRange`, so a future dataset release moves the
Gregorian span on its own and no view or model carries a range literal.

## What this cut does not do

It does not make the remaining table independently licensed, and no
documentation may say it does. Every year still shipped is
derived from the same base table (`medic/bikram-sambat`, itself a fork of
`alxndrsn/bikram-sambat.js`, which carries no licence file). The cut removes the
five years with the weakest corroboration; it does not resolve the provenance
chain, which is a separate track, tracked outside the engineering tickets.
Stating this honestly is the point of the record — a narrowing presented as a
licence fix would be worse than no cut all.

## Coverage gap: month boundaries are mostly unasserted

Found while cross-checking the table against a third party's public conformance
index, which tracks a real instance of this exact bug: the base table
`medic/bikram-sambat` shipped wrong Falgun and Chaitra lengths for BS 2081,
corrected in its PR #27 (merged 14 March 2025). **NepalKit's shipped rows match
the corrected values exactly**, so there is no defect in the shipped data.

The concerning part is that nothing here would have noticed. Demonstrated, not
theorised: restoring the pre-fix 2081 row — `[…, 29, 30, 30, 30]` instead of
`[…, 29, 30, 29, 31]` — leaves all 44 core tests green. The correction moves the
same number of days within the year, so:

- the year total is 366 either way, and `everyYearHasTwelveValidMonths` passes;
- 1 Baisakh 2082 is 2025-04-14 either way, so the whole New Year sweep passes;
- the round-trip and consecutiveness suites are internally consistent, so they
  pass by construction;
- `MonthStartTests` has no 2081 entry.

What it would break in the product: every Chaitra 2081 date shifts a day late,
and 31 Chaitra 2081 — a real date, 13 April 2025 — is rejected as invalid.

**The measured extent: 8 of the 110 supported years have any month-boundary
assertion at all**, and 10 have any `BSDay` assertion anywhere in the core suite.
The New Year sweep covers all 110 years but only at the year boundary, which is
blind to redistribution *within* a year.

So the honest statement of what the suite proves is narrower than it looks: it
proves the table is internally consistent and correct at year boundaries, and it
proves month boundaries for 8 years. It does **not** prove month boundaries for
the other 102. A second source is the only thing that can, and the cross-check
already had one — those arbitrated months are the ones that should each be an
assertion.

Partly addressed since: the arbitrated months now live in their own
`ArbitratedDisputeTests` suite, which added the one that was missing — 2084
Baisakh, arbitrated at 31 days but never asserted — and added a presence test so
the set cannot shrink silently during a refactor. Thirteen of the thirteen
recorded arbitration decisions are now asserted. (An earlier draft of this record
said those cases were unasserted. They were not; the count was wrong.)

The remaining 102 years are unchanged and still uncovered, and closing them needs
a cited published-calendar source per year, which does not exist for most of
them. Asserting dates without one would break the repo's sourcing rule, so the
gap stands as recorded rather than being papered over.

## Considered Options

**Ship 1970–1974 as they are, and document the single-source caveat.** Rejected.
The caveat would live in a repository file while the five years remained part of
the public conversion contract, which is the failure mode the provenance track
exists to close.

**Deprecate 1970–1974 before removing them.** Rejected. Deprecation keeps a
second conversion contract alive in the same binary, and nothing needs the old
one: 1913–1917 Gregorian is far outside any plausible use of a menu-bar date
utility.

**Hold the release until the upstream permission request is answered.** Rejected
as sequencing, not as principle. The request is external and unbounded; the five
uncorroborated years are a known, bounded defect that can be closed now, and
closing it does not depend on the request.
