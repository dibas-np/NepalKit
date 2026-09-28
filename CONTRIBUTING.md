# Contributing to NepalKit

Thanks for considering it. NepalKit is a small macOS menu-bar app, so the bar
for a change is not "does it compile" — it is **"is it true, and can you show
me you checked."**

Read [CODING_STANDARDS.md](CODING_STANDARDS.md) before writing code. It is short
and it is not advisory.

## The one thing that matters most

**The calendar data is the product's correctness core, and its provenance is
documented rather than assumed.** If your change touches month lengths, the
supported range, conversion, or the source record in [SOURCES.md](SOURCES.md),
it needs evidence, not reasoning:

```sh
python3 scripts/verify-data-sources.py
```

That script re-runs the whole comparison against pinned commits and prints which
shipped years each source cannot cover. If you change the table and the script
does not agree, the change is wrong — not the script.

`SOURCES.md` records what the data is, what is not licensed, and which months
were arbitrated. **Do not make it more confident than the evidence.** A claim
that cannot be checked from the repository is a bug, even when it is probably
true.

## Getting set up

The app's deployment floor is macOS 26, and `NepalKitCore` will not build
against anything older.

**Which Xcode is required is not settled, and this file will not pretend
otherwise.** It builds with Xcode 27, which is what the release pipeline uses.
The floor gate ([macos26-floor.yml](.github/workflows/macos26-floor.yml)) pins
**Xcode 26.6** on the `macos-26` runner and has still never run, so nobody has
proved 26.6 can build this — see ticket 04. If you hit something 26.6 cannot
compile, that is a finding worth reporting, not a local problem to work around.

```sh
git clone https://github.com/dibas-np/NepalKit.git
cd NepalKit
open NepalKit.xcodeproj
```

## Before you open a pull request

Run both suites. They are separate on purpose: one is the calendar, the other is
the application.

```sh
cd NepalKitCore && swift test          # the calendar: 47 tests
./scripts/run-app-tests.sh             # the app: 95 tests
```

`xcodebuild test` builds cleanly but the runner hangs in this environment, so
the app-layer suite goes through a SwiftPM harness instead — see
[ADR-0005](docs/adr/0005-app-layer-test-execution.md) for why. The harness
symlinks the real sources; it does not copy them.

If you have a built product to hand, the plist tests will read it:

```sh
NEPAKIT_BUILT_PLIST="$(xcodebuild -project NepalKit.xcodeproj -scheme NepalKit \
  -configuration Debug -showBuildSettings | sed -n 's/.*BUILT_PRODUCTS_DIR = //p')/NepalKit.app/Contents/Info.plist" \
  ./scripts/run-app-tests.sh
```

Without it, four tests **skip with a reason** rather than pass silently. That
is deliberate: a test that cannot check something must not report that it did.

## Style

- Swift, 4-space indent, no force-unwraps except where a value is known
  non-nil at the call site.
- Comments explain **why**, not what. Several comments in this repository
  record a decision and the alternative that was rejected; that is the house
  style and it is deliberate.
- Apple platform conventions are standing rules, not preferences. Use SF
  Symbols, follow the HIG, and match what the surrounding code already does
- Accessibility is not optional. Every surface needs a label, and the spoken
  form is a **separate channel** from the visual one — see
  [SpokenDate.swift](NepalKit/SpokenDate.swift) for why the two must not be
  conflated.

## Decisions, not just code

Anything that changes a supported-range boundary, the licence, the data
provenance, or a platform requirement needs a decision record in
[docs/adr/](docs/adr/). One paragraph: the context, the decision, and what it
costs. Existing ones are short; match that.

If you are changing a supported-range boundary, there is a specific rule about
narrowing versus widening — read [ADR-0010](docs/adr/0010-supported-range-narrowing.md)
first.

## Pull requests

- Branch from `main`, keep the history readable, and describe **why**.
- A pull request that changes data without re-running the verification script
  will be asked for the output.
- Continuous integration runs on the `macos26-floor` workflow. It is the
  deployment-floor gate: it proves the app builds, tests, and launches on the
  oldest macOS it claims to support, which is a different question from "does it
  work on my machine".

## Licensing of contributions

Contributions are accepted under the same terms as the project:
**GPL-3.0-or-later**. See [LICENSE](LICENSE).

NepalKit uses a **Developer Certificate of Origin (1.1)**. By submitting a
pull request you certify that:

1. Each commit is your original work, or you have the right to submit it under
   GPL-3.0-or-later; and
2. You are not aware of a licence or contract that would forbid the submission.

To sign off, add a `Signed-off-by:` line to every commit message, matching the
email you used:

```sh
git commit -s -m "Fix the converter clamp for Ashadh"
```

which produces:

```
Fix the converter clamp for Ashadh

Signed-off-by: Your Name <you@example.com>
```

`-s` adds it for you and opens an editor; `git config commit.signoff true` makes
it the default for every commit.

**Why DCO and not a CLA.** A CLA is a bilateral legal agreement that assigns
or licenses contributions under terms you may not want, and it adds friction and
a signing bot to every contribution. A DCO is a per-commit certification that
you had the right to submit what you submitted. It achieves the provenance
guarantee without asking anyone to sign away rights, which suits a project that
is already copyleft and does not need the extra copyright assignment.

A CLA would also be worth revisiting if the project grew a corporate
contributor base, where relicensing decisions start to matter.

> **Maintainer's note:** the DCO was adopted in September 2026, after the
> initial history was written. Earlier commits are therefore not signed off.
> That is normal and does not affect their provenance — they were written by
> the maintainer — but new commits should be.

## Reviewing

Reviews are about correctness and truthfulness, not style preference. If you
disagree with a decision, say so in the pull request rather than in a direct
message; the reasoning belongs in the open.

Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating.
