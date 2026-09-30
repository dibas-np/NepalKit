# macOS CI evidence as the deployment-floor release gate

> **Amended.** This ADR originally discharged ADR-0006's evidence gap with a job
> on the `macos-26` runner, so a green run was evidence about macOS 26 itself.
> That job now runs on `xcode-27`, which is macOS 27, because the `macos-26`
> toolchain could neither express the 26.6 floor nor open the project file.
> **The gate no longer executes the app on the floor.** The compile-time floor is
> still enforced; the runtime evidence is not. Read "Amended" below before relying
> on the original claim, which is stated above it and left in place as history.

**Refines ADR-0006.**

NepalKit's deployment floor is macOS 26 (ADR-0003), but no macOS 26 hardware was
available: every result to date came from macOS 27. ADR-0006 named that a
release-blocking evidence gap rather than an accepted unknown, and this records
how it is discharged. A GitHub Actions job on the `macos-26` runner image is
the accepted functional evidence. The gate is behavioural — the project opens,
builds, tests run, the application launches and survives, the menu-bar item
appears, no runaway launch loop occurs, and ⌘Q exits cleanly — and it is not a
pixel-rendering comparison. Reproducible CI evidence is strictly better than a
hand-run check on borrowed hardware, and it re-runs on every push rather than
once. macOS 27 remains the manual design-review platform, where pixel judgement
belongs.

This decision required downgrading the Xcode project file from object version
110 to object version 100. Object version 110 is Xcode 27.0's format and Xcode 26
cannot open it, so a `macos-26` job would fail before compiling a line. The
application source needed no accommodation: there are no availability gates
anywhere in the source, both SwiftPM manifests load under Xcode 26, and the
Liquid Glass API family is macOS 26 rather than macOS 27.

(An earlier version of this paragraph said "the highest API availability in use
is macOS 15". That was not checkable — it sat beside this record's own statement
that the Liquid Glass family is macOS 26, and the bundled `AppIcon.icon` Icon
Composer package is also a macOS 26 feature. What is actually true, and what
matters for the gate, is that nothing in the source is gated *above* the floor,
so the floor SDK can build it without a single availability check.)
Object version 100 is a valid common denominator readable by both toolchains, so
Xcode 27 continues to open the project.

**This has now happened twice, and the second time nobody noticed until CI
did.** The first was a deliberate adoption of an Xcode 27 feature. The second
was an accident: opening the project in Xcode 27 to build it is enough for
Xcode to rewrite the file into format 110, and that rewrite lands in whatever
commit comes next. The floor job's failure is the least useful kind available —

    xcodebuild: error: Unable to read project 'NepalKit.xcodeproj'.
    Reason: The project cannot be opened because it is in a future Xcode
    project file format (110).

— which names neither the setting that changed nor the file to put back, and
arrives as a red build on a pull request whose code is fine. Two CI jobs failed
that way before it was traced. It is now checked by `verify-deployment-floor.py`,
which fails with a message naming the setting, the limit, and this ADR. That gate
is the only thing stopping a third occurrence: the rewrite is a side effect of
using the tool, so no amount of care at commit time prevents it.

The accepted cost named above has now been paid. See "Amended" below.

## Amended: the gate moved to `xcode-27`, and what it cost

**Status: amended. The gate no longer runs on macOS 26.**

Both workflows moved off `macos-26` onto the `xcode-27` image, which is macOS 27.
This reverses the central claim of this ADR, so it is recorded rather than edited
away.

The move was forced by a bind, not chosen as a preference. The floor is macOS
26.6, and the Xcode 26.6 toolchain could not express it:

    warning: The macOS deployment target 'MACOSX_DEPLOYMENT_TARGET' is set to
    26.6, but the range of supported deployment target versions is 10.13 to
    26.5.99.

The toolchain whose job was to verify the floor could not represent the floor.
Separately, a maintainer on macOS 27 editing build settings in Xcode 27 rewrites
`project.pbxproj` into object version 110, and Xcode 26 reads only 100 — so every
such edit cost a manual downgrade, and that regressed twice before being gated.
The floor toolchain was simultaneously too old for the floor and too old for the
project file. There was no single-job answer: the toolchain that can read format
110 runs on macOS 27, and the OS that represents the floor is macOS 26.

What survives, and it is worth being exact about which is which:

- **The compile-time floor is still enforced.** A macOS 27-only API remains an
  error against a 26.6 deployment target, because `@available` and the SDK do not
  care which Xcode version is doing the enforcing. This is the failure this gate
  was written for — "compiles fine on a maintainer's Xcode, breaks the floor for
  everyone on macOS 26" — and it is still caught.
- **The floor's consistency is still gated.** `scripts/verify-deployment-floor.py`
  compares the project, the release script, the built product, and the project-file
  format against each other. It does not care which runner executes it.
- **Each run now records the macOS version it is evidence about** (`sw_vers`),
  which the old gate did not. A green run previously attested only that some
  macOS was green, which is the one claim a floor gate exists to make.

What is genuinely lost: **no CI job now executes the app on macOS 26.** The claim
"this runs on the floor" rests on the compile-time guarantee plus release evidence
rather than on CI. That is a real reduction in evidence and is not papered over.

Two names still say "macOS 26" and both are load-bearing rather than merely
stale. The workflow's job `name:` is required by the `main` ruleset by exact
string, and the workflow file keeps its filename because `release-tag.yml` calls
it as a reusable workflow by path. Renaming either alone blocks every future pull
request to `main` on a status check that can never be reported. Both were left
alone deliberately, and CONTRIBUTING.md records that they must change together or
not at all.

**The way back, if the lost evidence is worth paying for.** A second job on
`macos-26` would have to downgrade the object version before building, since
Xcode 26 cannot open a 110 project at all. That is automatable and was not done
here because it adds a macOS runner to every pull request to buy evidence for a
floor claim that the compile-time check already largely covers. It is the obvious
first move if a release ever needs macOS 26 runtime evidence.

Both workflows now resolve the image's default Xcode and assert a version floor
rather than pinning an exact version, because on a preview image the app directory
is `Xcode_27_beta_3.app` — an exact pin would name a beta that gets replaced, and
would break the gate on a toolchain change that is not a regression. The resolved
version is printed in every run's log, which preserves the property the old pin
existed to protect: a green run always states which toolchain produced it.

## Considered Options

**Acquire or borrow a macOS 26 machine for manual verification.** Rejected as the
primary mechanism: it is a one-time check that must be repeated by hand, and it
cannot run on every push. A second machine remains valuable for the distribution
gate, which is a different question and is handled separately.

**Lower the deployment floor to macOS 27.** Rejected. The floor is a deliberate
product decision (ADR-0003), not an accident of the toolchain available.

**Ship on macOS 27 evidence and record macOS 26 as a known issue.** Rejected.
That is exactly the outcome ADR-0006 was written to prevent.
