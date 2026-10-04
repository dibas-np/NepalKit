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

That script compares the shipped table with the sole pinned askbuddie base and
prints every difference. Use `--baseline scripts/data-sources-baseline.json` to
fail on changes to the recorded observation. The baseline deliberately permits
the corrections and provisional projection documented in SOURCES.md.

`SOURCES.md` records the MIT notice, local decisions and evidence limits.
Do not describe a comparison result as official attestation or remove a
provenance gap without supporting evidence. ADR-0014 governs the current policy.

## Getting set up

The app's deployment floor is macOS 26, and `NepalKitCore` will not build
against anything older.

**The floor is macOS 26.6, and CI runs Xcode 27.** The floor gate
([macos26-floor.yml](.github/workflows/macos26-floor.yml)) runs on the `xcode-27`
image and has completed successfully: core suite, app-layer suite, build, and a
launch that survives and exits without a relaunch loop.

This needs stating plainly, because the gate's name and the ruleset's required
check still say "macOS 26" while the runner is macOS 27. So be clear about what
that does and does not mean:

- **The compile-time floor is enforced.** A macOS 27-only API is still an error
  against a 26.6 deployment target, whatever Xcode enforces it. That is the
  failure mode the gate exists for, and it still holds.
- **The app is no longer *run* on macOS 26.** That claim rests on the
  compile-time guarantee plus release evidence, not on CI.

The move off `macos-26` was forced, not preferred. Xcode 26.6's SDK tops out at
deployment target 26.5.99, so it could not even express a 26.6 floor, and Xcode
26 cannot open the object-version-110 project file that Xcode 27 writes — every
build-settings edit prompted an upgrade that silently broke the gate. The header
of `macos26-floor.yml` records the trade and the way out; ADR-0007 records the
decision.

If you hit something 26.6 cannot compile, that is a regression against a claim
the gate still enforces — report it rather than working around it locally.

**The app and Xcode test targets compile in Swift 6 language mode** — `SWIFT_VERSION = 6.0`
with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, in `project.pbxproj` — and the
SwiftPM app and test targets must keep that language mode and default isolation.
The two are separate compilers over the same sources:
`xcodebuild build-for-testing` compiles the app and hosted test bundle, and
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

It runs these eleven, in this order:

```sh
# 1. compile and link the app and Xcode test bundle
xcodebuild -project NepalKit.xcodeproj -scheme NepalKit -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" CODE_SIGNING_ALLOWED=NO build-for-testing
python3 scripts/test_swiftlint.py          # 2. bootstrap and all maintained Swift files
./scripts/swiftlint.sh lint --strict

swift test --package-path NepalKitCore      # 3. the calendar: 93 tests
./scripts/run-app-tests.sh                  # 4. the app: 179 tests
python3 scripts/test_dataset_parsers.py     # 5. the month table against the parsers
python3 scripts/test_update_cask.py         # 6. downloaded app identity and version
python3 scripts/test_update_changelog.py    # 7. the changelog generator
python3 scripts/test_unregister_launchservices.py  # 8. the release pipeline's LaunchServices hygiene
python3 scripts/test_verify_appcast.py      # 9. the appcast verifier
python3 scripts/test_verify_deployment_floor.py
python3 scripts/verify-deployment-floor.py  # 10. the floor is one number everywhere
xcodebuild test -project NepalKit.xcodeproj -scheme "NepalKitWatch Watch App" \
    -configuration Debug \
    -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=27.0' \
    CODE_SIGNING_ALLOWED=NO                   # 11. the Watch app and its complications
```

Gate 8 is the only one that touches the machine rather than the repository: it
registers and then unregisters real throwaway app bundles in this session's
LaunchServices database. It is there because `scripts/unregister-launchservices.sh`
guards a failure that is invisible from the outside — a bundle registered under a
temp path that is later deleted cannot be unregistered, so a release pipeline
that cleans up without unregistering first leaves one stale entry per run
forever. Ninety-plus of them for this bundle id is what it looked like in
practice. Gate 10 runs the floor verifier's own suite before the verifier,
because `scripts/test_verify_deployment_floor.py` is run by no other gate
here. CI runs both commands too: `.github/workflows/macos26-floor.yml` runs
them on every pull request after its Mac build, so the checker compares the
built plist that build exports (`NEPAKIT_BUILT_PLIST`) against the sources,
while `.github/workflows/pages.yml` still runs them with no build, comparing
the sources to each other, when `appcast.xml` changes on `main`, or on
demand.

The first lint run downloads SwiftLint 0.65.1 into the ignored `.build/tools`
cache after checking its published checksum. For compiler-backed unused-import
and unused-declaration checks, run `./scripts/swiftlint.sh analyze
--compiler-log-path <log>` with a log from a successful Xcode build.

The counts are what the runners printed when this was written. A pull request
that changes them re-pins both numbers in the same commit.

Two of those eleven are the direct consequence of gates that once reported green
while something was wrong, so they are worth explaining rather than just
listing.

**The build is first** because nothing else compiles the app: both test suites run
through a SwiftPM harness that excludes `NepalKitApp.swift` and
`SparkleUpdateService.swift`, correctly, and the script suites do not build Swift
at all. Plan 021 set `SWIFT_VERSION = 6.0` and shipped a file the app could not
compile, and twenty-two plans passed every gate in this list.

**The floor check runs after the build** because it compares the sources against
each other rather than trusting any one of them. The app target built at 26.6 while
`package-release.sh` said 26.0, so the appcast gate — which reads the floor from
that file — reported `26.0 matches the app's floor` and passed, while the feed
offered updates to systems that could not launch the build. Nothing in the list
above it could have caught that, because they all agreed with each other. The Watch
gate now runs after it too, and is last only because it needs a watchOS simulator
runtime rather than because it depends on the floor.

`check-all.sh` deliberately does **not** run the `verify-*` scripts. The one
that matters is `python3 scripts/verify-data-sources.py`, the provenance gate:
it needs network access, and it is the first thing to reach for whenever the
calendar table, the supported range or [SOURCES.md](SOURCES.md) changes — see
"The one thing that matters most" above. The others are release-time gates over
packaged artifacts and the published feed. CI runs all of them on any change
that touches them, so this command is the local half and not a replacement.

The two Swift suites stay separate on purpose: one is the calendar, the other is
the application.

The app-layer suite runs through a SwiftPM harness that symlinks the real
sources. It was introduced after a hosted Xcode runner hang; the hosted suite
also passes on the current toolchain. See
[ADR-0005](docs/adr/0005-app-layer-test-execution.md) for the history.
To run the hosted suite directly:

```sh
xcodebuild -project NepalKit.xcodeproj -scheme NepalKit -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" CODE_SIGNING_ALLOWED=NO test
```

If you have a built product to hand, the plist tests will read it:

```sh
NEPAKIT_BUILT_PLIST="$(xcodebuild -project NepalKit.xcodeproj -scheme NepalKit \
  -configuration Debug -showBuildSettings | sed -n 's/.*BUILT_PRODUCTS_DIR = //p')/NepalKit.app/Contents/Info.plist" \
  ./scripts/run-app-tests.sh
```

Prefer that recipe to leaving it to discovery. A discovered product is used only
when it is **newer than the source that builds it**; an older one is refused,
because those tests exist to catch keys that reach the product — and a
product from last week is not what this source produces. Either way the run
prints what it found and what it compared against. Without a usable product,
the suite's tests **skip with a reason** rather than pass silently. That is deliberate:
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
  corrections and projection, so a red gate means the table, a parser, or a source changed
  without documenting the new observation. Regenerating the baseline
  (`python3 scripts/verify-data-sources.py --update-baseline`) is a deliberate
  act that must land in the same pull request as the table change it reflects.
- Continuous integration runs on the `macos26-floor` workflow. It is the
  deployment-floor gate: it proves the app builds, tests, and launches on a macOS
  toolchain, which is a different question from "does it work on my machine". It
  no longer runs *on* the oldest supported macOS — the gate's header records what
  that costs and why.
- That gate is also a **required status check** on `main` (branch ruleset
  `main`, enforcement active — checkable under
  Settings → Rules → Rulesets). Its single required check is named
  `build, test, and launch on macOS 26`. The repository owner is a bypass
  actor, so a broken gate can never lock a solo maintainer out of their own
  repository; for everyone else it cannot be skipped.
- **That name and the ruleset must change together, or not at all.** The check
  name above no longer describes what the job does — the job runs on macOS 27 —
  but renaming the `name:` alone would leave the ruleset demanding a check that
  can never be reported, which blocks every future pull request to `main` with
  no failure to diagnose. To correct it, edit the ruleset's required check under
  Settings → Rules → Rulesets *and* the job's `name:` in the same change. This
  was nearly shipped the other way round.

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
