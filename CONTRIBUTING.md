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

It runs these fourteen, in this order:

```sh
# 1. compile and link the app and Xcode test bundle
xcodebuild -project NepalKit.xcodeproj -scheme NepalKit -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" CODE_SIGNING_ALLOWED=NO build-for-testing
python3 scripts/test_swiftlint.py          # 2. bootstrap and all maintained Swift files
./scripts/swiftlint.sh lint --strict

swift test --package-path NepalKitCore      # 3. the calendar: 93 tests
./scripts/run-app-tests.sh                  # 4. the app: 184 tests
python3 scripts/test_dataset_parsers.py     # 5. the month table against the parsers
python3 scripts/test_update_cask.py         # 6. downloaded app identity and version
python3 scripts/test_update_changelog.py    # 7. the changelog generator
python3 scripts/test_unregister_launchservices.py  # 8. the release pipeline's LaunchServices hygiene
python3 scripts/test_verify_appcast.py      # 9. the appcast verifier
python3 scripts/test_verify_bestpractices_json.py  # 10. the badge entry's own checks
python3 scripts/verify-bestpractices-json.py # 11. the badge entry is well-formed
python3 scripts/measure-coverage.py    # 12. coverage has not fallen below its floor
python3 scripts/test_verify_deployment_floor.py
python3 scripts/verify-deployment-floor.py  # 13. the floor is one number everywhere
xcodebuild test -project NepalKit.xcodeproj -scheme "NepalKitWatch Watch App" \
    -configuration Debug \
    -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=27.0' \
    CODE_SIGNING_ALLOWED=NO                   # 14. the Watch app and its complications
```

Gate 8 is the only one that touches the machine rather than the repository: it
registers and then unregisters real throwaway app bundles in this session's
LaunchServices database. It is there because `scripts/unregister-launchservices.sh`
guards a failure that is invisible from the outside — a bundle registered under a
temp path that is later deleted cannot be unregistered, so a release pipeline
that cleans up without unregistering first leaves one stale entry per run
forever. Ninety-plus of them for this bundle id is what it looked like in
practice. Gate 13 runs the floor verifier's own suite before the verifier,
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

Two of those fourteen are the direct consequence of gates that once reported green
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

`check-all.sh` does **not** run `verify-data-sources.py`, and that exclusion is
deliberate: the provenance gate needs network access, and it is the first thing
to reach for whenever the calendar table, the supported range or
[SOURCES.md](SOURCES.md) changes — see "The one thing that matters most" above.
The other release-time verifiers are likewise absent, because they run over
packaged artifacts and the published feed rather than over a checkout.

Two `verify-*` scripts are in the list, and the exceptions are worth naming so
the rule above does not read as broader than it is:
`scripts/verify-bestpractices-json.py` is gate 11 because it needs nothing but the
committed entry file, and `scripts/verify-deployment-floor.py` is gate 13 because
it needs only the built product. A structural check that only runs when someone
remembers to run it is not a gate. Everything that needs the network, a
credential, or a built artifact stays out.

CI runs both, in `badge-entry.yml`, and runs the checker's own suite before the
checker — a validator that has quietly stopped validating reports green, which
is the failure mode this ladder exists to prevent. That claim was aspirational
until that workflow existed: the two gates ran only when a human ran this
script. Two further gates are deliberately local-only and say so in the same
workflow: LaunchServices unregistration (gate 8) needs a GUI login session a
runner does not have, and the coverage floor (gate 12) needs the macOS
toolchain and about six minutes. Every other gate here runs in CI, in the
workflow that owns it. This command is the local half and not a replacement:
it is the only thing that runs all fourteen in one pass.

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

## Tests: what has to come with a change

**A change to behaviour comes with a change to the tests that cover it, in the
same commit. A pull request that changes what the software does and does not
change a test is incomplete, not merely under-tested.**

That is the policy. The rest of this section is what "major change" and "update
the tests" mean here, because a policy that needs interpretation gets ignored
the first time it is inconvenient.

### What counts as a major change

Add or update tests for:

- **Any change to the calendar.** Month lengths, the supported range, conversion,
  clamping, weekday derivation, or the dataset. This is the correctness core and
  it is CODEOWNERS'd for exactly this reason; `CONTRIBUTING.md` opens by saying
  the bar is "is it true, and can you show me you checked".
- **Any change to a value the user sees or hears** — a date, a name, a digit
  script, a spoken form, a VoiceOver label.
- **Any new App Intent, or a change to what one returns.** Intents are a public
  interface: Shortcuts users depend on the returned field names and types.
- **Any new release-contract artifact**: a key in `Info.plist`, an entitlement,
  a deployment target, a feed URL, the bundle identifier.
- **Any bug fix.** A regression test that fails without the fix is the evidence
  the fix was needed. This is not optional and does not scale down for "small"
  bugs — the small ones are the ones that come back.

### What does not need a new test

- Comment, documentation, and comment-only changes.
- Pure refactors with no observable behaviour change. Say so in the pull request;
  do not add a test that asserts the shape of the code rather than its behaviour.
- Layout and visual design. **A warning:** this repository has already had a gate
  report green while something was wrong, twice, and both times because a check
  was measuring the wrong thing. If you cannot test it, do not claim it is
  tested. Gate 14 below and the fresh-Mac procedure exist because app-layer and
  on-device behaviour has limits, and those limits are documented rather than
  papered over.

### How to run them, and how to read the result

`./scripts/check-all.sh` runs every gate in order and names each one. The full
list, in order, is above. Two conventions matter more than the individual
commands:

- **A skipped test is not a passing test.** The plist tests skip with a reason
  when there is no built product to read, and the Watch suite skips with an
  annotation when no usable watchOS runtime is installed. Both are deliberate: a
  test that cannot check something must not report that it did. If you see a
  skip, fix the preconditions rather than reading it as a pass.
- **Run the suite locally before opening the pull request.** It is the same
  fourteen gates CI runs, and a red local run is a faster red than a red one after
  review.

### Why a test-only commit is still welcome

A pull request that adds coverage without changing behaviour is useful and will
be merged. What is not acceptable is a behaviour change whose tests arrive
later, or in a follow-up, because a follow-up is a promise with no gate behind
it.

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

Changing an OpenSSF Best Practices answer in
[`.bestpractices.json`](.bestpractices.json) is the same kind of change: the
justification has to point at evidence in this repository, not assert a fact. See
[docs/bestpractices-entry.md](docs/bestpractices-entry.md) for which answers a
ruleset or workflow change can silently invalidate — relaxing branch protection
is a small diff that makes a `Met` untrue without touching that file.

Anything that changes a supported-range boundary, the licence, the data
provenance, or a platform requirement needs a decision record in
[docs/adr/](docs/adr/). One paragraph: the context, the decision, and what it
costs. Existing ones are short; match that.

If you are changing a supported-range boundary, there is a specific rule about
narrowing versus widening — read [ADR-0010](docs/adr/0010-supported-range-narrowing.md)
first.

## Size of a change

**A pull request should do one thing.** That is the whole policy, and the rest of
this section is what "one thing" means when a change touches more than one file,
which most of them do.

**Aim for under about 400 changed lines, excluding generated files and
lockfiles.** Above that, prefer splitting. Below it, do not split for the sake of
the number — a three-line fix with a test is one change, not two.

Split when the change contains separable work:

- a refactor and a behaviour change → the refactor lands first, on its own
- a data change and the code that consumes it → the data and its provenance note
  together, the consumer separately if it can land after
- a bug fix and the cleanup it made convenient → the fix first, alone
- one feature and an unrelated fix found along the way → two pull requests, and
  the second says so

Keep together when separation would leave the repository in a state nobody wants
to stop in:

- a test and the fix it proves — a red test on its own is not a contribution
- a schema or dataset change and everything needed for it to be correct
- a licence or entitlement change and the release that has to carry it

**Two exceptions, both deliberate.**

*A dependency bump with the change that needs it.* A Dependabot pull request that
also fixes the fallout of the bump is one change, because the bump alone would
break something. Say in the description that it does both.

*A gate that fails until another change lands.* When a fix is only correct
alongside its gate, the gate is part of the fix. Every gate in this repository
was added that way, and none of them landed as a separate pull request.

### Why this rule is here

This section is `small_tasks` on the OpenSSF badge entry, and the honest version
of why it exists is that it is a policy, not a measurement. Large changes are
harder to review and this repository has one reviewer, so the limit is set by
what one person can hold in their head — not by a number anyone measured.

What would make it more than a policy: opening an issue that takes a week. The
honest answer today is that nothing in this repository's history has been tracked
that way, so the claim is that changes are small, not that they are decomposed.

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
  Settings → Rules → Rulesets). Its name is `build, test, and launch on macOS
  26`. The repository owner is a bypass actor, so a broken gate can never lock a
  solo maintainer out of their own repository; for everyone else it cannot be
  skipped.
- **That name and the ruleset must change together, or not at all.** The check
  name above no longer describes what the job does — the job runs on macOS 27 —
  but renaming the `name:` alone would leave the ruleset demanding a check that
  can never be reported, which blocks every future pull request to `main` with
  no failure to diagnose. To correct it, edit the ruleset's required check under
  Settings → Rules → Rulesets *and* the job's `name:` in the same change. This
  was nearly shipped the other way round.
- The ruleset requires **more than one check now**, and the same
  edit-the-ruleset-together rule applies to every one of them:

  | Required check | Workflow | Why it is required rather than reported |
  | --- | --- | --- |
  | `build, test, and launch on macOS 26` | `macos26-floor.yml` | The deployment-floor claim. Nothing else attests it |
  | `every commit carries a DCO sign-off` | `dco.yml` | The DCO is promised in this file. A check nobody has to pass is a promise nobody has to keep |
  | `Analyze (swift)`, `Analyze (python)`, `Analyze (actions)` | `codeql.yml` | Static analysis. A finding in a list nobody reads has changed nothing |
  | `no vulnerable dependency is introduced` | `dependency-review.yml` | The same argument, for dependencies |

  Adding a required check is a change to what can block a merge, so it is a
  deliberate act rather than a tidy-up. Removing one is more so: a required
  check that silently stops being required is a security control that stopped
  existing without anyone deciding.
- **Adding a dependency?** Read [`docs/dependencies.md`](docs/dependencies.md)
  first. The `dependency-review` gate fails the pull request if what you add has
  a known advisory at `moderate` severity or above, and
  [`docs/security-assessment.md`](docs/security-assessment.md) records why that
  severity threshold is where it is. Dependabot cannot watch this project's
  Swift pin at all, which that document explains.

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
