# macOS 26 CI evidence as the deployment-floor release gate

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

The accepted cost is that adopting a future Xcode 27-only *project-file* feature
requires raising the object version again, which breaks this gate and forces it
to be re-evaluated. That is a deliberate trade: a continuously re-verified
deployment floor is worth more than unearned access to project-file features.

The CI workflow pins an explicit `DEVELOPER_DIR` rather than relying on the
runner image's default Xcode, which has already moved 26.4.1 → 26.5 → 26.6 and
will keep moving.

## Considered Options

**Acquire or borrow a macOS 26 machine for manual verification.** Rejected as the
primary mechanism: it is a one-time check that must be repeated by hand, and it
cannot run on every push. A second machine remains valuable for the distribution
gate, which is a different question and is handled separately.

**Lower the deployment floor to macOS 27.** Rejected. The floor is a deliberate
product decision (ADR-0003), not an accident of the toolchain available.

**Ship on macOS 27 evidence and record macOS 26 as a known issue.** Rejected.
That is exactly the outcome ADR-0006 was written to prevent.
