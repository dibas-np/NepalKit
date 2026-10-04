# Test coverage

The number, what it means, and why it is not a target yet.

**Measured 2026-10-04 at `280a3ed`, by `scripts/measure-coverage.py`.**

| Suite | Files | Lines | Regions | Functions |
| --- | --- | --- | --- | --- |
| `NepalKitCore` — the calendar engine | 9 | **85.62%** | 78.30% | 81.43% |
| `NepalKit` — the app layer | 42 | **35.03%** | 53.02% | 52.76% |
| **Combined** | **51** | **43.96%** | **57.48%** | **57.82%** |

Reproduce it:

```sh
./scripts/measure-coverage.py
```

## Read the two suites separately

The combined figure is close to meaningless on its own, and the split is the
point:

- The calendar engine — conversion, month lengths, formatting, spoken dates — is
  **85.62%** covered, because it is pure logic with an exhaustive round-trip
  suite. This is the part where a bug is a wrong date.
- The app layer is **35.03%** covered, because most of it is SwiftUI.

The app layer is 82% of the source lines and 41% of the coverage. A single
combined percentage hides that the part which is easy to get wrong is well
covered and the part which is mostly declarative layout is not.

## Why there is no target

The OpenSSF badge asks for 80% and 90% statement coverage and 80% branch
coverage. This project is at 43.96% / 43.96% / 57.48%. Those answers are `Unmet`
and writing a target above the truth would be a gate that fails every day.

**The gap is not a chore; it is a refactor.** Of the 42 app files, 1,352 lines —
23% of the layer — sit in files at exactly 0%:

| File | Lines |
| --- | --- |
| `GeneralSettingsView.swift` | 319 |
| `SettingsView.swift` | 253 |
| `ConverterView.swift` | 221 |
| `AboutSettingsView.swift` | 173 |
| `MenuBarSettingsView.swift` | 107 |
| `PopoverFooter.swift` | 100 |

Every one is a SwiftUI view. Covering them needs one of two things, and neither
is a test-writing exercise:

1. **UI tests.** [ADR-0005](adr/0005-app-layer-test-execution.md) records that
   hosted `xcodebuild test` hangs on this toolchain. That is why the app-layer
   suite is a SwiftPM harness that symlinks the sources — which works for logic
   and cannot instantiate a view.
2. **A view-logic extraction.** `CODING_STANDARDS.md` already requires view logic
   to live in a view model so it can be tested. Applying that to the six files
   above would move their logic into testable types and leave the views thin. It
   is the better answer and it is a real piece of work — roughly the size of the
   Settings rewrite in 1.4.1.

## What the gate does instead

`scripts/measure-coverage.py` records a floor in `scripts/coverage-floor.json`
and **fails when coverage drops below it**. It has no target.

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

## Two measurement details that are easy to get wrong

Both were got wrong in the first version of this script, and both produced a
confident wrong answer rather than an error.

**llvm-cov strips the leading `/` from report paths.** Comparing them against an
absolute repository prefix therefore matches *nothing* — which looks exactly like
"no product source was compiled". Both sides are normalised before comparison.

**The row is thirteen fields: `(count, missed, percent)` four times over.** A
parser that filters out the `-` standing in for "no data" shifts every later
column and reports a plausible number. This script parses positionally and
asserts the field count.

There is a third, subtler one: an earlier version of the subject-file filter used
an absolute path, so it silently counted 9 of the app layer's 42 files and
reported 62.65% where the truth is 35.03%. A coverage tool that measures the wrong
files is worse than none, because the number looks real.

## Branches are not measured

Swift emits no branch data, so llvm-cov reports zero for its Branches column. The
table above reports **regions**, which is llvm-cov's nearest equivalent, and the
script calls it `regions` rather than `branches` for exactly that reason. Quoting
it as branch coverage would be passing one metric off as another, which is how a
badge answer ends up claiming something the code does not support.
