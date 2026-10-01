# App-layer test execution: committed SwiftPM harness

The app-layer tests in `NepalKitTests/` are the only automated guard on
settings persistence and uniform display, but `xcodebuild test` originally hung before
connecting in the development environment. It reproduced with an empty test, so
the investigation attributed it to the LSUIElement host plus the Xcode beta, and Apple
labeled it a possible bug. A SwiftPM harness runs the suite successfully, so that
harness is committed along with a single command that executes the whole
app-layer suite: a fresh checkout must always have a documented, reproducible way
to run these tests. On 2026-10-01, after aligning the target isolation settings,
the hosted runner completed all 167 tests in 24 suites. The earlier hang no
longer reproduces on this toolchain. The SwiftPM harness remains useful for
running the app logic without launching an application host.

Deleting the tests was rejected: unreachable tests are worse than no tests,
because they read as coverage while guarding nothing.

## Harness structure: symlinks, not copies

The first version of this harness held *copies* of the app sources and test
files, and rewrote `@testable import NepalKit` to `@testable import Harness` in
each test file. Those copies silently drifted: they predated the menu-bar
midnight timer and the hardened converter clamping, so a "24 tests passing"
result was being reported against code the app no longer contained. Ticket 04
and 05 both described their runs as "byte-identical sources", which was true when
written and stopped being true within a day.

`scripts/apptests/` now symlinks `Sources/NepalKit` and `Tests/NepalKitTests`
straight to the real directories, and names the target `NepalKit` so the real
test files compile with no edits. Drift is no longer discouraged, it is
impossible: there is only one copy of the source. That claim is about the
*sources*, and it is worth being exact about that — one copy removes the
possibility of the tested text differing from the shipped text, but it says
nothing on its own about which files are in the tested set. Those are the next
paragraph's subject, and the two are separate.
`scripts/run-app-tests.sh` fails with exit 1 if either path stops being a
symlink, so a well-meaning copy cannot silently reintroduce the problem.

## The five files outside the test boundary

`scripts/apptests/Package.swift:41-49` excludes five paths, and the list is
worth reading in full because the fifth is the one with a consequence:

- `NepalKitApp.swift` owns `@main`, which a library target cannot have.
- `Assets.xcassets`, `Info.plist` and `NepalKit.entitlements` belong to the
  Xcode app bundle rather than to a SwiftPM library target.
- `SparkleUpdateService.swift` imports Sparkle, and the harness links only
  `NepalKitCore`.

The first four cost coverage that nothing depends on. The fifth does not, and
the reason is worth stating precisely rather than leaving to the exclusion
list's own comment.

`SparkleUpdateService.swift:131-135` maps Sparkle's `SPUNoUpdateFoundReason`
onto `UpdatePolicy.NoUpdateFoundKind`, and that mapping is **outside** the test
boundary. It is the boundary's real cost: a typo there reports a feed that
could not be fetched or verified as "you are on the latest version", which is
the one error a user cannot detect for themselves, and no test in this harness
can catch it — the file cannot be compiled without the framework the harness
deliberately does not link.

The `UpdatePolicy` half *is* covered, by the harness that does compile it:
`NepalKitTests/UpdatePolicyTests.swift:21-26` asserts the classification for all
three kinds, so the policy and its outcomes are tested even though the mapping
into it is not. A test of the mapping would have to reach Sparkle's enum
through a framework the harness does not link, so it is recorded here as known
uncovered rather than left to look like an oversight.

## Compile the hosted Xcode tests too

`scripts/check-all.sh` uses `xcodebuild build-for-testing` before running the
SwiftPM harness. This compiles and links the hosted test bundle without starting
the runner. An app-only build missed test failures caused by the Xcode test
target using Swift 5 while the app used Swift 6 with Main Actor isolation.

Both Xcode targets now use Swift 6, Main Actor default isolation, and approachable
concurrency. Both SwiftPM targets also declare Main Actor default isolation.
The built-plist lookup is explicitly nonisolated because Swift Testing evaluates
its enabled trait from a Sendable closure. It reads the product without keeping
shared mutable state.
