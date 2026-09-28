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
application source needed no accommodation: the highest API availability in use
is macOS 15, there are no availability gates, both SwiftPM manifests load under
Xcode 26, and the Liquid Glass API family is macOS 26 rather than macOS 27.
Object version 100 is a valid common denominator readable by both toolchains, so
Xcode 27 continues to open the project.

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
