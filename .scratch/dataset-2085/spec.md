# Dataset extension to 2085 BS

Status: waiting

> Written 2026-09-29, while 2084 is still projected and the Samiti has published
> through 2083 BS only. Nothing in this ticket is actionable until the trigger
> below fires, and the first decision it asks for is not about shipping anything.
>
> The procedure is `docs/release-evidence/dataset-extension-procedure.md`. This
> ticket is the calendar and the two decisions; the procedure is how they get
> carried out.
>
> **Updated 2026-10-11 for ADR-0014.** The table's sole historical base is now
> askbuddie, pinned at `d3475606`, plus 14 explicit local corrections; the
> multi-source corroboration this ticket first described is no longer the
> policy. The monthly check and its `last_checked:` record moved into the
> procedure, and a scheduled job now fails when that record is overdue.

## Why this exists

The shipped table ends at 2084 BS, which is **2028-04-12 Gregorian** — the last
day 30 Chaitra 2084 can express. Past that, every install's Bikram Sambat date
goes unavailable. The app is honest about that boundary: the popover names the
last supported year rather than showing a blank, and the boundary sentence is
read from the dataset rather than written as a literal, so it moves with the
data. But honesty about a boundary is not the same as extending it, and a menu
bar utility whose date goes dark on every install on one day in 2028 has failed
at the one job it exists to do.

So this is a calendar item, not a feature request. It has an external trigger
that the project does not control, which makes the lead time the thing to
manage.

## The trigger

As recorded on 28 September 2026, the Nepal Panchanga Nirnayak Samiti approves
each year's patro a few months before that year begins, it **has published
through 2083 BS only**, and the official determination of **2084 is expected
around Magh 2083 BS (January–February 2027)**. The 2083 almanac was confirmed
published in December 2025, following the same pattern as 2082.

So the first decision comes in **January–February 2027**, roughly three months
before 2084 BS begins on 14 April 2027. That three months is the entire budget
for a decision, a transcription, a baseline regeneration and a release.

**Target the release months before 2028-04-12, not weeks.** The deadline is
softer than the date looks — nothing crashes, and the boundary state is honest —
but a user on 2028-04-13 gets no Bikram Sambat date at all, and "we were three
weeks away" is not a thing that can be said to them afterwards.

## The two decisions, in this order

### 1. Attest or contradict the shipped 2084 row

The shipped 2084 row is NepalKit's own **provisional projection**, a 365-day
development and testing row, not attributed to the askbuddie base (ADR-0014,
SOURCES.md). ADR-0014 keeps it as a separate, recorded exception to "nothing is
extrapolated".

When the Samiti publishes 2084, compare all twelve months of the published
almanac against the shipped row. Compare months, not totals: a transposition
preserves the total, and every one of the twenty recorded arbitrations is one.

- **Identical** — the projection was right and the data does not change. The
  projected-versus-published table in `SOURCES.md` moves 2084 to attested, and
  the ADR-0001 tension note is **resolved, not deleted**. Move to decision 2.
- **Different** — the shipped row was wrong. That is a data fix, not an
  extension: a breaking change to the conversion contract, a dataset major bump,
  and the full release, with ADR-0010 as the precedent for how a table change
  under a decision is handled. Days move; a user's stored BS date may now
  convert differently.

### 2. Ship 2085 only once it is attested

Compare the Samiti's published 2085 almanac with the pinned askbuddie base
(`scripts/verify-candidate-year.py 2085`) and record every difference and how it
was resolved in SOURCES.md. Other converters may be consulted as targeted
evidence, but they are not additional bases (ADR-0014), and agreement between
projections is not attestation. **2085 waits for the Samiti's almanac.**

A green run of `scripts/verify-candidate-year.py` is not a decision. It
informs one.

## What is not decided here

- Whether the identifier `CalendarDataset.v2` is renamed to `.v3` at extension
  time, or whether the dataset version moves without it. ADR-0010's rule
  points one way; the procedure's step 5 covers versioning, and the
  maintainer takes that decision with the evidence in front of them.
- Whether a second independent 2085 reproduction can be obtained, and what is
  done if it cannot.
- The release date, which follows from the trigger rather than being chosen
  now.

## Monthly check, from 1 January 2027 onward

Moved to the procedure's "Monthly Samiti check" section, which also holds the
`last_checked:` record that the `patro-reminder` job reads.
