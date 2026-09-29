# Dataset extension to 2085 BS

Status: waiting

> Written 2026-09-29, while 2084 is still projected and the Samiti has published
> through 2083 BS only. Nothing in this ticket is actionable until the trigger
> below fires, and the first decision it asks for is not about shipping anything.
>
> The procedure is `docs/release-evidence/dataset-extension-procedure.md`. This
> ticket is the calendar and the two decisions; the procedure is how they get
> carried out.

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

`SOURCES.md`, in "Why 2084 is the upper bound — and a correction", records the
schedule as of 28 September 2026: the Nepal Panchanga Nirnayak Samiti approves
each year's patro a few months before that year begins, it **has published
through 2083 BS only**, and the official determination of **2084 is expected
around Magh 2083 BS (January–February 2027)**. The 2083 almanac was confirmed
published in December 2025, following the same pattern as 2082.

So the first decision comes in **January–February 2027**, roughly three months
before 2084 BS begins on 13 April 2027. That three months is the entire budget
for a decision, a transcription, a baseline regeneration and a release.

**Target the release months before 2028-04-12, not weeks.** The deadline is
softer than the date looks — nothing crashes, and the boundary state is honest —
but a user on 2028-04-13 gets no Bikram Sambat date at all, and "we were three
weeks away" is not a thing that can be said to them afterwards.

## The two decisions, in this order

### 1. Attest or contradict the shipped 2084 row

The shipped 2084 row is a **projection**. `SOURCES.md` is explicit that this is
in tension with ADR-0001's rule that nothing is extrapolated, and that it is
recorded rather than smoothed over. Three sources carry it — `medic` (base),
`askbuddie` (MIT), and the Kathmandu Metropolitan City calendar — with
`subeshb1/Nepali-Date` alone against them, differing in five months and on the
year total (366 against 365).

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

Corroborate 2085 across the KMC calendar, the four pinned community tables, and
at least one published-Patro reproduction, and record who agrees. Then apply
the rule, from `SOURCES.md`, verbatim:

> Still not shipped: nothing is extrapolated
> (ADR-0001), and agreement between projections is not attestation.

Only the Samiti's published almanac makes a year shippable. `medic`,
`askbuddie`, `go-bs` and KMC currently agree on the same 2085 row of
`[31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30]` (366 days), and
`subeshb1/Nepali-Date` differs — but that agreement is the precondition for
shipping 2085, not permission to ship it. **2085 waits for the Samiti, not for
KMC.**

A green run of `scripts/verify-candidate-year.py` is not a decision. It
informs one.

## What is not decided here

- Whether the identifier `CalendarDataset.v2` is renamed to `.v3` at extension
  time, or whether the dataset version moves without it. ADR-0010's rule
  points one way; the deviation options are in the procedure's step 3d, and the
  maintainer takes that decision with the evidence in front of them.
- Whether a second independent 2085 reproduction can be obtained, and what is
  done if it cannot.
- The release date, which follows from the trigger rather than being chosen
  now.

## Monthly check, from 1 January 2027 onward

Once a month, until the trigger fires:

1. **Read the Samiti's publication notices on `npns.gov.np`.** Publication is
   the trigger; the notice is where it is announced. Absence of a notice in
   January is not evidence the year will not be published — 2083 was confirmed
   in December 2025.
2. **If it published, read the almanac itself.** A notice proves a year was
   determined; it does not give you the twelve month lengths, and a
   republication is not the almanac.
3. **Then run the tooling**, which is corroboration and not the gate:

   ```sh
   python3 scripts/verify-candidate-year.py 2084
   python3 scripts/verify-candidate-year.py 2085
   ```

If February 2027 passes with no publication, escalate rather than let the
calendar run down. The Samiti's schedule is the one input this project cannot
substitute for, and a slip in it needs more lead time, not less.
