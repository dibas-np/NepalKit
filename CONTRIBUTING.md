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

**Xcode 26.6 is enough, and that is now evidence rather than hope.** The floor
gate ([macos26-floor.yml](.github/workflows/macos26-floor.yml)) pins Xcode 26.6
on the `macos-26` runner and has completed successfully: core suite, app-layer
suite, build, and a launch that survives and exits without a relaunch loop. The
release pipeline uses Xcode 27, so 26.6 is the floor that matters and it holds.
The release pipeline uses Xcode 27, and the Xcode project format stays at the
level the floor toolchain reads — **decline Xcode 27's project-upgrade
prompt**. Accepting it silently breaks the floor gate for every later pull
request, with no local symptom.

If you hit something 26.6 cannot compile, that is a regression against a claim
the gate now enforces — report it rather than working around it locally.

**The app target compiles in Swift 6 language mode** — `SWIFT_VERSION = 6.0`
with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, in `project.pbxproj` — and the
SwiftPM harness must stay in that same language mode. The two are separate
compilers over the same sources: `xcodebuild build` compiles what ships and
`./scripts/run-app-tests.sh` compiles the sources it symlinks, and the harness
excludes the two files most in need of strict checking, so if the modes drift
apart the shipping configuration is left unchecked by any gate. Change one and
change the other in the same commit.

```sh
git clone https://github.com/dibas-np/NepalKit.git
cd NepalKit
open NepalKit.xcodeproj
```

## Before you open a pull request

One command runs every automated gate, and names each one as it goes:

```sh
./scripts/check-all.sh
```

It runs these five, in this order:

```sh
cd NepalKitCore && swift test               # the calendar: 55 tests
./scripts/run-app-tests.sh                  # the app: 141 tests
python3 scripts/test_dataset_parsers.py     # the month table against the parsers
python3 scripts/test_update_changelog.py    # the changelog generator
python3 scripts/test_verify_appcast.py      # the appcast verifier
```

The counts are what the runners printed when this was written. A pull request
that changes them re-pins both numbers in the same commit.

`check-all.sh` deliberately does **not** run the `verify-*` scripts. The one
that matters is `python3 scripts/verify-data-sources.py`, the provenance gate:
it needs network access, and it is the first thing to reach for whenever the
calendar table, the supported range or [SOURCES.md](SOURCES.md) changes — see
"The one thing that matters most" above. The others are release-time gates over
packaged artifacts and the published feed. CI runs all of them on any change
that touches them, so this command is the local half and not a replacement.

The two Swift suites stay separate on purpose: one is the calendar, the other is
the application.

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

Prefer that recipe to leaving it to discovery. A discovered product is used only
when it is **newer than the source that builds it**; an older one is refused,
because those five tests exist to catch keys that reach the product — and a
product from last week is not what this source produces. Either way the run
prints what it found and what it compared against. Without a usable product,
five tests **skip with a reason** rather than pass silently. That is deliberate:
a test that cannot check something must not report that it did.

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
- Continuous integration runs the comparison against the committed baseline
  (`data-sources.yml`): the baseline's differing months are the recorded
  arbitrations, so a red gate means the table, a parser, or a source changed
  without re-arbitrating. Regenerating the baseline
  (`python3 scripts/verify-data-sources.py --update-baseline`) is a deliberate
  act that must land in the same pull request as the table change it reflects.
- Continuous integration runs on the `macos26-floor` workflow. It is the
  deployment-floor gate: it proves the app builds, tests, and launches on the
  oldest macOS it claims to support, which is a different question from "does it
  work on my machine".
- That gate is also a **required status check** on `main` (branch ruleset
  `main`, enforcement active — checkable under
  Settings → Rules → Rulesets). Its single required check is named
  `build, test, and launch on macOS 26`. The repository owner is a bypass
  actor, so a broken gate can never lock a solo maintainer out of their own
  repository; for everyone else it cannot be skipped.

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

`-s` adds the line for you — with `-m`, as above, the commit is created
directly with no editor; drop `-m` to compose the message (sign-off included)
in your editor. `git config commit.signoff true` makes it the default for
every commit.

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
