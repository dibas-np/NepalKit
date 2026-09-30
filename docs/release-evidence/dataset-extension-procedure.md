# Dataset extension to 2085 BS — procedure

The trigger is a publication that happens once a year, so this procedure is run
once a year, months apart, by whoever is maintaining at the time. It is not run
in advance of the publication, and it is not run from a projection.

Two branches, and the difference between them is the whole reason this document
exists:

- **Branch A** — the Samiti published 2084, and we check whether it published
  *our* 2084. Usually the answer is yes and no data changes.
- **Branch B** — we extend the table to 2085.

Run Branch A first, always. A Branch A contradiction changes what Branch B is
transcribing, and doing it in the other order risks shipping a new row on top of
a row that was already wrong.

Everything in a branch is a decision the maintainer makes while holding the
evidence. This document does not make them for you, and its "decide here"
steps are numbered so the decision can be recorded when it is taken.

## 1. Trigger and clock

**What you are waiting for.** The Nepal Panchanga Nirnayak Samiti approves each
year's patro a few months before that year begins. As of the check recorded in
`SOURCES.md` ("Why 2084 is the upper bound — and a correction", verified
28 September 2026), the Samiti **has published through 2083 BS only**, and the
official determination of **2084 is expected around Magh 2083 BS
(January–February 2027)**. The 2083 almanac was confirmed published in December
2025, following the same pattern as 2082.

**Why that means the clock starts in January 2027 and not later.** 2084 BS runs
from 13 April 2027 (1 Baisakh 2084) to 11 April 2028, so a determination
published in Magh 2083 BS (January–February 2027) arrives roughly three months
before the year it describes begins. That lead time is the entire budget:

```sh
# The monthly check, from 1 January 2027 onward.
# 1. Did the Samiti publish? Its notices are on npns.gov.np — read them.
# 2. If it did, what does the almanac itself say?
# 3. Then, and only then, run the corroboration tooling.
python3 scripts/verify-candidate-year.py 2084
python3 scripts/verify-candidate-year.py 2085
```

**Do not** treat the absence of a notice in January as evidence the year will
not be published. 2083 was confirmed in December 2025; the timing moves.

**The hard backstop.** The last day the shipped table can express is
**2028-04-12 Gregorian** (30 Chaitra 2084 BS). Past it, every install's BS date
goes unavailable. This is honest — the popover names the last supported year
rather than showing a blank — but it is not a soft failure the user can fix, and
the release that extends the range should ship **months** before it, not weeks.
If February 2027 has passed with no publication, escalate rather than let the
calendar run down: a slip of the Samiti's schedule is the one input this project
cannot substitute for.

## 2. Branch A — attest or contradict the shipped 2084 row

The shipped 2084 row is, right now, **projected**. `SOURCES.md` states this
plainly: 2084 is projected rather than published, and shipping it is "in tension
with ADR-0001's rule that nothing is extrapolated". Three sources agree on the
values — `medic` (base), `askbuddie` (MIT), and the Kathmandu Metropolitan City
calendar — with `subeshb1/Nepali-Date` alone against them on five months and on
the year total (366 against 365).

The shipped row, read out of
`NepalKitCore/Sources/NepalKitCore/CalendarDataset.swift`:

```swift
2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
```

**Step A1 — fetch the published almanac.** Obtain the 2084 patro the Samiti
approved, in the form it was published. Record where it came from and its date.
A republication is not the almanac: see the "Do not" section.

**Step A2 — compare month by month.** Write the published twelve month lengths
beside the row above. Do not compare totals; a transposition preserves the total
and every such dispute in `SOURCES.md` is one. Compare all twelve months.

**Step A3 — also re-run the live spot-check**, because the sources are live and
results can change under us:

```sh
scripts/check-kathmandu-calendar.py --dump 2084
python3 scripts/verify-candidate-year.py 2084 31,31,32,31,31,30,30,30,29,30,30,30
```

**Step A4 — decide.** Two outcomes, and they are not symmetric:

| Outcome | What it means | What you do |
| --- | --- | --- |
| **Published row is identical** | The projection was right, and now it is attested | Branch B only. The data does not change. |
| **Published row differs** | The shipped 2084 row was wrong | This is a **data fix**, not an extension. Stop and follow the fix path below. |

**Identical → resolve the tension, do not delete it.** `SOURCES.md`'s projected-
versus-published table moves 2084 from "projected" to attested, and the ADR-0001
tension note is **resolved, not removed**: record that a projected row shipped,
what it was corroborated against, and that the publication confirmed it. The
note is the reason a reader trusts the surrounding rows, and deleting it would
erase the fact that the rule was ever in tension with what shipped. Keep the
disputed-month record for 2084 too — `subeshb1` is still the outlier, and a
resolved dispute stays recorded (see `SOURCES.md`'s per-dispute format).

**Different → the fix path.** The shipped 2084 row was wrong, and every artefact
in Branch B step (g) applies: a breaking change to the conversion contract, a
dataset major bump, and the full release. ADR-0010's worked example is the
precedent, because it is the last time this table changed under a decision
rather than under an expansion. Specifically:

- Days move. A changed month length shifts every date after it, so this is not a
  cosmetic correction — a user who stored a BS date may now get a different
  Gregorian answer for the same input.
- The dataset version takes a **major** bump, per ADR-0010's rule that narrowing
  or correcting the conversion contract is a data-contract major, and the
  identifier rename rule in ADR-0010 applies (`CalendarDataset.v2` → `.v3`).
- The year total matters more than the individual months here: the 2084 dispute
  already turned on a 365-against-366 total, and a wrong total moves real dates
  for anyone in the second half of the year.
- Extend `ArbitratedDisputeTests` with the corrected months, so the fix is
  asserted rather than merely recorded.
- Record the arbitration in `SOURCES.md`'s disputed-months table with the
  published almanac as the deciding source — a stronger class of evidence than
  the KMC grid and the community tables that decided the twenty recorded months.

## 3. Branch B — extend the table to 2085

Work these in order. Each step assumes the previous one passed.

### 3a. Corroborate the 2085 row across independent sources

Corroboration is what tells you whether to expect the Samiti's almanac to agree
with what you have. It does not license shipping the year — that is step 3b.

```sh
# The live government calendar. KMC publishes 2083-2085 only.
scripts/check-kathmandu-calendar.py --dump 2085

# The four pinned community tables, each reported separately, including
# any that publish no row for the year.
python3 scripts/verify-candidate-year.py 2085
```

**Record who agrees with whom, by name.** For the record as it stands today,
this is the 2085 landscape; treat it as the baseline to re-run, not as a
substitute for re-running it:

| Source | 2085 | Licence |
| --- | --- | --- |
| `medic/bikram-sambat` (base) | `[31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30]` (366) | Apache-2.0, unlicensed upstream |
| `askbuddie/bikram-sambat` | same row | MIT |
| `SuprimKhatri77/go-bs` | same row | MIT |
| Kathmandu Metropolitan City | same row (per `SOURCES.md`) | **none stated** |
| `subeshb1/Nepali-Date` | **differs, 365 days** | MIT |

`SOURCES.md` records KMC's 2085 as `[31, 32, 31, 32, 30, 31, 30, 30, 29, 30,
30, 30]` (366 days), "which matches the Hamro Patro / `nepali-datetime` pair
independently reported as agreeing on that year".

**Decide: is one independent published-Patro reproduction in hand?** The plan
for this work asks for at least one. KMC is a government body's republication of
the national calendar and is the strongest single source available for a future
year — but it states no licence and nothing from it is vendored, so it is
corroboration and adjudication, never a source. If you cannot obtain a second
independent reproduction, record that gap rather than counting KMC twice.

**Do not** treat `subeshb1`'s 2085 disagreement as settled by the majority. The
2084 record is the precedent: `subeshb1` was the outlier there, `medic` and
`askbuddie` were the base, and the deciding source was KMC. The same pattern
does not automatically repeat, and a disagreement is a disagreement until the
Samiti's almanac settles it.

### 3b. The attestation rule — read this out loud before 3c

From `SOURCES.md`, verbatim:

> Still not shipped: nothing is extrapolated
> (ADR-0001), and agreement between projections is not attestation.

And on what a source match does and does not establish:

> **What this does not establish.** A match is corroboration of the *values*, not
> proof of *official attestation*. KMC republishes the national calendar, but
> showing a future BS year is also exactly what a projection does [...] Only the
> Samiti can attest a year.

And ADR-0001, the rule this project is bound by:

> The table contains only verified calendar data: no extrapolated or projected
> years. Its supported BS range is explicitly defined by the dataset itself and
> expands only when new official Patro data becomes available.

**So: a green `verify-candidate-year.py` summary is not permission to ship 2085.**
It is four tables agreeing, which is the precondition for shipping and not the
condition for it. 2085 waits for the Samiti, not for KMC.

**Decide: has the Samiti published 2085?** If no, stop here. Re-run the monthly
check. Nothing in Branch B from 3c onward is permitted before the answer is yes.

### 3c. Transcribe the published row

Read the transcription contract in `CalendarDataset.swift`'s doc-comment block
first. It is a contract, not a description, and three clauses in it are traps:

- **Transcribe from a current checkout, not a pre-2025-03-14 one.** The base
  table shipped wrong Falgun and Chaitra lengths for 2081, corrected in PR #27.
  The correction is dangerous to miss because *the year total is 366 either way*
  — 29+31 and 30+30 redistribute the same days — so a stale transcription
  produces the right 1 Baisakh 2082 and passes every year-level check while
  shifting all of Chaitra 2081 by a day. Re-verify the 2081 rows after any
  re-transcription.
- **2085 is absent on purpose** in the current file, and that sentence is what
  you replace. Its reason — "the source has it" is not a reason to widen the
  conversion contract — stops being true only when the Samiti publishes, so
  rewrite the reason, do not just delete it.
- Provenance is stated per-dataset-version in the same block. The 2.0.0
  paragraph is the 1975 narrowing; the 2085 extension gets its own.

Then, in the data block:

1. Add the 2085 row, transcribed from the almanac, in the same positional form.
2. **Extend the `supportedRange` upper bound** from `2084` to `2085`. This is a
   declared range, not derived (ADR-0002), so it is edited by hand — and the
   `init` precondition means a declared year with no twelve-month row fails at
   construction rather than corrupting conversions.
3. **Verify `gregorianEnd`; never hand-edit what derives.** It is computed from
   `supportedRange.upperBound`'s Chaitra month length, is documented as "derived,
   never stored", and is what both the About tab's supported-range row and the spoken boundary
   sentence read — so the table change moves the Gregorian end on its own and
   there is no Gregorian literal to hunt down. Confirm the new value rather than
   typing one in.
4. Update the doc-comment block: the range sentence, the version paragraph, and
   whatever the "absent on purpose" note became.

### 3d. The identifier rename — decide this, do not take it from this document

ADR-0010's rule, read from its own words:

> The bundled static is renamed `CalendarDataset.v1` → `CalendarDataset.v2` to
> match. The identifier is public API of the core package, and leaving a symbol
> named `v1` that declares `"2.0.0"` would be a name that lies about the contract
> it names.

Applied to this extension, that means `CalendarDataset.v2` → `.v3`, and a
**dataset major bump** in the `version` string. That much is determined by the
rule. **What you decide here is whether to apply the rule, and any deviation
from it.** Present the options with the evidence and let the maintainer choose:

| Option | For | Against |
| --- | --- | --- |
| **A. Rename `v2` → `v3`, dataset `2.0.0` → `3.0.0`** | Follows ADR-0010 exactly. The identifier names the contract it names. The app-side sweep is now one line plus the rename, because plan 013 consolidated the app onto `AppData.dataset`. | Touches public API of the core package, so it is a breaking change for anyone importing `NepalKitCore` directly. |
| **B. Keep `.v2`, bump only the version string** | Smallest diff. | Directly violates ADR-0010's stated reason: a symbol named `v2` declaring `"3.0.0"` is the exact "name that lies" the record rejects. It would also contradict `AppData.swift`'s own doc-comment, which points at ADR-0010 as the reason for naming the dataset once. |
| **C. Rename and deprecate `.v2` as an alias** | No source break for core consumers. | ADR-0010 considered a deprecation for the *range* and rejected it: it keeps a second conversion contract alive in the same binary, and nothing needs the old one. An alias here is that same shape. |

**Decide: A, B, or C, in writing, before touching the rename.** Whichever you
choose, record it as an ADR refinement or a new ADR — ADR-0010 is the precedent
record, and a deviation that is not written down is the failure mode that
record exists to prevent.

**The app-side sweep, after plan 013.** ADR-0010's rename "touched four app
sources and eight test files". The app has since been consolidated: every model,
scene body, and preview reads `AppData.dataset`, and no other file names a
`CalendarDataset.v*` literal. So the sweep is:

1. `NepalKit/AppData.swift` — the single line naming the constant.
2. The rename itself in `CalendarDataset.swift`.
3. Test expectations that name the version or range (see 3e).

Re-grep before assuming: `grep -rn "CalendarDataset.v" NepalKit/` should return
only the doc-comment and the one line in `AppData.swift`.

### 3e. Regenerate the CI baseline, in the same PR

The data-sources gate is landed and real: `.github/workflows/data-sources.yml`
runs `scripts/test_dataset_parsers.py` and then
`python3 scripts/verify-data-sources.py --baseline scripts/data-sources-baseline.json`.
That gate does not fail on any diff; it fails when the comparison *result*
changes from the committed baseline.

```sh
python3 scripts/verify-data-sources.py --update-baseline
```

Do this in the **same PR** as the table change. Explain every new differing
month against `SOURCES.md` in the PR description — the baseline's differing
months *are* the recorded arbitrations, so an unexplained entry makes the gate
weaker rather than keeping it current.

**The parser suite's real-table constants move in the same PR too.** These are
assertions about the shipped table's shape, and they are the ones that will fail
first:

- `scripts/test_dataset_parsers.py:263` — `self.assertEqual(len(rows), 110)`
- `scripts/test_dataset_parsers.py:264` — `self.assertEqual(min(rows), 1975)`
- `scripts/test_dataset_parsers.py:265` — `self.assertEqual(max(rows), 2084)`

(all three inside `ShippedRangeTests.test_shipped_table_shape`)

And on the app side:

- `NepalKitTests/AppMetadataTests.swift:171` — `CalendarDataset.v2.version == "2.0.0"`
- `NepalKitTests/AppMetadataTests.swift:172` — `.supportedRange == 1975 ... 2084`
- `NepalKitTests/DatasetBoundaryTests.swift:34,84-85` — the boundary day and the
  spoken "Supported through 2084 BS" string
- `NepalKitTests/SpokenDateTests.swift`, test
  `supportedRangeIsSpokenWithoutTheEnDash` — the shown range "1975–2084 BS" and
  its spoken form. Named rather than cited by line, because this is the one
  assertion here a refactor has already moved once: 8c0b155 moved the spoken forms
  into the core, and the line numbers this entry carried before that now point
  into an unrelated punctuation sweep. A test name survives that move; a line
  number does not.
- `NepalKitTests/ConverterModelTests.swift:43-44,86` — `bsYears`, an Ashar 2084
  month-length assertion, and the `2084-12-30 ↔ 2028-04-12` anchor comment

**Decide:** whether each boundary test is *updated* to the new end or *retained*
deliberately at the old one. `DatasetBoundaryTests` exists to assert the boundary
state users actually reach; a test that keeps asserting the old end may be
exactly the regression you want, or it may be about to become a second dataset
release away from truthful. That is a judgement about intent, not a mechanical
find-and-replace.

### 3f. Update the app-side copy

- **README's range sentence**, `README.md:106` — "NepalKit converts **1975–2084
  BS** (1918-04-13 through 2028-04-12 Gregorian)." Both endpoints change; the
  lower bound does not.
- **README's dataset-version line**, `README.md:115`, and the bullet at
  `README.md:120-124` recording that "2084 is projected, not published". After
  Branch A that bullet is about a published year and must stop saying otherwise.
- **The dataset doc comment**, as in 3c.

**About and the boundary sentence need no change, and that is worth verifying
rather than assuming.** `Strings.supportedThrough(_:digits:)` takes the BS year
as a parameter (`NepalKit/Strings.swift:18`) — it composes a string, and holds no
range literal. The caller supplies `dataset.supportedRange.upperBound`
(`NepalKit/PopoverView.swift:259`). So the boundary sentence, the spoken
boundary sentence, and the About range all follow the dataset. If you find
yourself editing one of them by hand, the dataset was not the source of the
value and something else is carrying a literal.

### 3g. Release

Ship through the normal path: `scripts/package-release.sh`, producing the signed,
notarized, stapled `.dmg`, with release notes in `CHANGELOG.md` and
`scripts/release-notes/<version>.html`.

**The release notes must tell users the range moved.** An install that updates
and finds 2085 answerable is the point of the release; a changelog that says only
"data updates" hides a change to a conversion contract. State the new range, the
old range, and that dates from the old end are unaffected. If Branch A
contradicted the shipped row, that is the headline instead, and it needs its own
paragraph — some users' stored BS dates now convert differently.

### 3h. Record the evidence

- **`SOURCES.md`**, in its existing per-dispute format: every comparison output
  and every arbitration decision, with the deciding source named. If a 2085
  disagreement exists between sources, it is recorded the way the 2084 one is —
  a resolved dispute is part of the record, and an unresolved one is a finding.
- **Release evidence** under `docs/release-evidence/`, following this document:
  what was fetched, from where, when, what it was compared against, and what was
  decided.
- **The ADR**, for anything 3d did not settle by rule.

## Do not

- Do not extrapolate past the attested year. Adding 2086 because 2085 was
  attested is ADR-0001's prohibition, and a row the Samiti has not published is
  a projection regardless of how many tables carry it.
- Do not ship a range change without the regenerated CI baseline in the same PR.
  A baseline that lags the table makes the gate pass on a comparison nobody ran.
- Do not describe the extended table as differently-licensed. ADR-0010's "What
  this cut does not do" applies to an extension **verbatim**: the remaining table
  is still derived from the same base source, `medic/bikram-sambat`, itself a
  fork of `alxndrsn/bikram-sambat.js`, which carries no licence file. Adding an
  attested year changes the range, not the provenance chain. `SOURCES.md`'s "The
  honest summary" says this in the same terms, and a reader who checks upstream
  will find exactly that.
- Do not let the Samiti's *publication* of a projection-corroborating year
  substitute for reading the almanac itself. A publication notice proves a year
  was determined; it does not give you the twelve month lengths. Read them from
  the almanac and record where you read them.
- Do not take a republication as the almanac. KMC, Hamro Patro, and the
  converter sites are corroboration and adjudication. The Samiti's own patro is
  the attested row.
- Do not treat a green agreement summary as permission. See 3b.

## Failure modes

| What you see | What it means | What to do |
| --- | --- | --- |
| **Red data-sources gate** during this work | **Expected.** You changed the table, so the comparison result changed, which is exactly what the gate detects | Regenerate deliberately with `--update-baseline` in the same PR, and explain each new differing month against `SOURCES.md`. Do not "fix" it by widening the comparison. |
| **Red parser suite** | The real-table constants in `scripts/test_dataset_parsers.py` still assert the old shape | Update `110` / `1975` / `2084` (lines 263-265) in the same PR, per 3e. |
| **Red KMC spot-check** | The live government site now disagrees, or is down | A disagreement means re-adjudicate: treat it exactly as Branch A's contradiction path, because a live government source contradicting the shipped row is a provenance event, not a flaky read. A site that is merely unreachable is not a finding — record that the check could not run. |
| **A pinned source's 2084/2085 row contradicts `SOURCES.md`** | A provenance event, not a script output | Stop. Report it. A disagreement with the shipped table is only an event when `SOURCES.md` claims that source *agrees* with the shipped table for that year; the recorded disagreements are deliberate and the baseline encodes them. |
| **Impossible year total** from `check_impossible` | The source table contains an error | It is a note about the source, not about your candidate. Record it and do not transcribe a row you cannot reconcile. |

## Record

Note the date, the Samiti notice you acted on, every source fetched and its URL,
every comparison output, and every decision with the evidence behind it. Also
record what you decided **not** to do — which branch, which options you rejected
in 3d, whether you obtained a second independent 2085 reproduction. A reader
re-running this in 2030 should be able to tell which parts of the record were
observed and which were decided.
