# Test coverage

The number, what it means, and why it is not a target yet.

**Measured 2026-10-12 at `fdee48b`, by `scripts/measure-coverage.py`.**

| Suite | Files | Lines | Regions | Functions |
| --- | --- | --- | --- | --- |
| `NepalKitCore` — the calendar engine | 12 | **89.23%** | 83.16% | 86.54% |
| `NepalKit` — the app layer | 50 | **36.05%** | 63.83% | 59.35% |
| **Combined** | **62** | **42.24%** | **67.54%** | **63.12%** |

Core's files are counted once, in their own row: the app row holds `NepalKit/`
only, although the app-test harness links `NepalKitCore`. The combined row is
Σhit/Σlines across both suites, not a mean of two percentages.

Reproduce it:

```sh
./scripts/measure-coverage.py
```

## Read the two suites separately

The combined figure is close to meaningless on its own, and the split is the
point:

- The calendar engine — conversion, month lengths, formatting, spoken dates — is
  **89.23%** covered, because it is pure logic with an exhaustive round-trip
  suite. This is the part where a bug is a wrong date.
- The app layer is **36.05%** covered, because most of it is SwiftUI.

The app layer holds 88% of the executable lines the two suites instrument —
4,657 of 5,270 — and returns 36.05% line coverage where the calendar engine
returns 89.23%. A single combined percentage hides that the part which is easy
to get wrong is well covered and the part which is mostly declarative layout is
not.

## Why there is no target

The OpenSSF badge asks for 80% and 90% statement coverage and 80% branch
coverage. This project is at 42.24% lines / 67.54% regions / 63.12% functions. Those answers are `Unmet`
and writing a target above the truth would be a gate that fails every day.

**The gap is not a chore; it is a refactor.** The eight files below hold 1,737
lines — 37% of the app layer's 4,657 executable lines — and every one of them is
at exactly 0%:

| File | Lines |
| --- | --- |
| `GeneralSettingsView.swift` | 443 |
| `SettingsView.swift` | 248 |
| `ConverterView.swift` | 237 |
| `MonthGridDayDetailCard.swift` | 223 |
| `AboutSettingsView.swift` | 191 |
| `MenuBarSettingsView.swift` | 160 |
| `PopoverFooter.swift` | 119 |
| `DestinationTabs.swift` | 116 |

These are llvm-cov executable-line counts and include compiler-expanded
`#Preview` code, so they can exceed a file's physical length.

Every one is a SwiftUI view. Covering them needs one of two things, and neither
is a test-writing exercise:

1. **UI tests.** [ADR-0005](adr/0005-app-layer-test-execution.md) records that
   hosted `xcodebuild test` hangs on this toolchain. That is why the app-layer
   suite is a SwiftPM harness that symlinks the sources — which works for logic
   and cannot instantiate a view.
2. **A view-logic extraction.** `CODING_STANDARDS.md` already requires view logic
   to live in a view model so it can be tested. Applying that to the eight files
   above would move their logic into testable types and leave the views thin. It
   is the better answer and it is a real piece of work — roughly the size of the
   Settings rewrite in 1.4.1.

## What the gate does instead

`scripts/measure-coverage.py` records a floor in `scripts/coverage-floor.json`
and **fails when coverage drops below it**. It has no target. The gate enforces
the floor for each suite as well as for the combined row, so a fall in the app
layer cannot hide behind a gain in the core.

That is a deliberate inversion. A ratchet that only moves up is honest about a
number that is currently low; a target set above the truth is a lie that fails
every day and gets ignored, which is the failure
[macos26-floor.yml](adr/0007-macos26-ci-release-gate.md)'s header describes at
length.

Raising the floor is a deliberate act:

```sh
./scripts/measure-coverage.py --update   # and say in the commit why
```

The `--update` flag exists so that lowering the floor is a visible, argued act
rather than something that happens by editing a number.

## Measurement details that are easy to get wrong

The first two were got wrong in the first version of this script, and each of
these produced a confident wrong answer rather than an error.

**llvm-cov strips the leading `/` from report paths.** Comparing them against an
absolute repository prefix therefore matches *nothing* — which looks exactly like
"no product source was compiled". Both sides are normalised before comparison.

**The row is thirteen fields: `(count, missed, percent)` four times over.** A
parser that filters out the `-` standing in for "no data" shifts every later
column and reports a plausible number. This script parses positionally and
asserts the field count.

**The app harness links the core.** Core rows therefore appear in the app suite's
llvm-cov report and must be filtered out per suite. Counting core's 9 files in
both suites inflated the app and combined figures by about 4.7 points (34.79%
against 30.12% for the app, 43.59% against 38.91% combined, at the commit that
fixed it). The combined row must also be weighted by executable lines: a mean
weighted by file count counted a 6-line file like a 300-line one.

**An absolute-path filter measured the wrong files.** An earlier version of the
subject-file filter used an absolute path, so it silently counted 9 files instead
of the app layer's and reported 62.65%, roughly double the app layer's real
figure. A coverage tool that measures the wrong files is worse than none, because
the number looks real.

## Branches are not measured

Swift emits no branch data, so llvm-cov reports zero for its Branches column. The
table above reports **regions**, which is llvm-cov's nearest equivalent, and the
script calls it `regions` rather than `branches` for exactly that reason. Quoting
it as branch coverage would be passing one metric off as another, which is how a
badge answer ends up claiming something the code does not support.
