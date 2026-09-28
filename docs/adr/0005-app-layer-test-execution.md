# App-layer test execution: committed SwiftPM harness

The app-layer tests in `NepalKitTests/` are the only automated guard on
settings persistence and uniform display, but `xcodebuild test` hangs before
connecting in the development environment — it reproduces with an empty test, so
it is the LSUIElement host plus the Xcode beta rather than app code, and Apple
labels it a possible bug. A SwiftPM harness runs the suite successfully, so that
harness is committed along with a single command that executes the whole
app-layer suite: a fresh checkout must always have a documented, reproducible way
to run these tests. `xcodebuild test` stays documented as a known toolchain
issue, and establishing CI on a known-good Xcode is the follow-up that supersedes
this arrangement.

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
impossible: there is only one copy of the source.
`scripts/run-app-tests.sh` fails with exit 1 if either path stops being a
symlink, so a well-meaning copy cannot silently reintroduce the problem.

Two exclusions are deliberate: `NepalKitApp.swift` owns `@main`, which a library
target cannot have, and `Assets.xcassets` belongs to the Xcode app bundle.
