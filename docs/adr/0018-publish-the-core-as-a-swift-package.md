# Publish the core as a Swift package

Date: 2026-11-04
Status: accepted; the API notes in point 2 and the platforms in point 4 are
superseded by [ADR-0019](0019-a-general-purpose-core-api.md)

## Context

NepalKitCore is a local package that only the app and the Watch products use,
and the roadmap listed a public API under *Not planned*. The core is the part
other apps could use: offline Bikram Sambat conversion over a table with
recorded provenance, Nepal Time, and Nepali formatting. Publishing it means
deciding where it lives (SwiftPM needs a manifest at a repository root), how
it versions (ADR-0009 already keeps three independent numbers), its licence
(GPL keeps it out of most apps, including App Store ones), and its platforms
(iOS was neither declared nor tested).

## Decision

1. **A read-only mirror, `dibas-np/NepalKitCore`.** The core is still
   developed only here. The mirror's main is
   `git subtree split --prefix=NepalKitCore`, which anyone can rerun and
   compare. Issues and the wiki are off, and rulesets with no bypass block
   force-pushing or deleting main and moving or deleting a `v*` tag.

2. **Its own semver, from 0.1.0.** Mirror tags are `v<version>`; the source
   commit here gets `core-v<version>`, which neither the `v*` ruleset nor
   `release-tag.yml` matches. Both are signed with the commit-signing key.
   `scripts/release-core.sh` cuts releases from `develop`, so they do not wait
   for `main`'s checks. Its gate is the core suite on macOS, iOS and watchOS,
   run in the split. It verifies every tag, new or already published, against
   the published key before pushing anything, and pushes the mirror
   atomically. `scripts/test_release_core.py` tests it.

   The API stays below 1.0 until it is reviewed for outside use. It still
   carries app-only types (`MenuBarFormat`, `WatchDayDisplay`,
   `ComplicationAccessibility`, `WatchDayCopy`) and module-level functions
   like `bsToAD`.

3. **The core is MIT.** The maintainer is its only human author; the other
   commit identities are AI tools. `NepalKitCore/LICENSE` and the core's SPDX
   headers say MIT, the askbuddie notice is unchanged, and everything else
   stays GPL-3.0-or-later. This grants nothing new for the calendar data
   (SOURCES.md, *Copyright scope*).

4. **iOS 26 is declared.** It is compile-checked. The suite runs on the iOS 27
   Simulator, the only iOS runtime on the release machine.

## Consequences

- The roadmap's *Not planned* row narrows to a plugin interface; 0.x limits
  the API commitment until the review.
- No new credential exists, and no workflow can reach the mirror.
- `git subtree split` drops commit signatures, so the signed tags are what
  consumers verify ([release verification](../release-verification.md#verifying-a-nepalkitcore-release)).
- Changes under `NepalKitCore/` are contributed under MIT.
- A dataset change reaches consumers only through a package release. A
  narrowed range (ADR-0010) is breaking: a minor bump under 0.x, major after.

## Considered options

- **A root `Package.swift` here.** Rejected: the package would version with
  the app's `v*` tags, already at 1.7.0.
- **Move the core out and consume it remotely.** Rejected: a dataset fix and
  the app change it needs could no longer share a pull request.
- **Keep the core GPL.** Rejected by the maintainer.
- **1.0.0 now.** Rejected: it would freeze app-only names.

This ADR amends ADR-0014's licence statement for the core only.
