# Publish the core as a Swift package

Date: 2026-11-04
Status: accepted

## Context

NepalKitCore has been a local package since 1.0. The Mac app and the Watch
products reference it by path, and nothing outside this repository could
depend on it. The roadmap listed "a public API or plugin interface" under *Not
planned*, because a published surface is a commitment a solo maintainer has to
keep.

The core is the part of NepalKit that is useful to other apps: offline
Bikram Sambat conversion over a table with recorded provenance, Nepal Time, and
Nepali formatting. Publishing it raises four questions, each with a cost:

- **Where it lives.** SwiftPM resolves a package only from the root of a
  repository, and the manifest here is at `NepalKitCore/Package.swift`.
- **How it versions.** ADR-0009 keeps the app version, the build number and the
  dataset version independent. A library adds a fourth number with its own
  contract.
- **What licence it carries.** Under GPL-3.0-or-later the core could be linked
  only by GPL software, which in practice also keeps it out of App Store apps.
- **Which platforms it claims.** The manifest declared macOS and watchOS only,
  the two floors NepalKit ships on. iOS, where most consumers would be, was
  neither declared nor tested.

## Decision

1. **A mirror repository, `dibas-np/NepalKitCore`.** This repository stays the
   only place the core is developed. The mirror's main is
   `git subtree split --prefix=NepalKitCore` of it, pushed from the release
   machine by `scripts/release-core.sh`. The split is deterministic, so anyone
   can rerun it and compare commits. The mirror is read-only, and its README
   sends issues and pull requests here. Its issues and wiki are off. Its
   rulesets block force-pushing or deleting main and updating or deleting a
   `v*` tag, with no bypass actor, so a published release cannot move.

2. **Its own semantic version, starting at 0.1.0.** Release tags on the mirror
   are `v<version>`, signed with the key that signs this repository's commits
   and tags. Each release also gets a signed `core-v<version>` tag here, on the
   source commit. That prefix matches neither the `v*` tag ruleset nor
   `release-tag.yml`, so a package release can never be read as an app release.
   The package's v* tags never exist in this repository: the script creates
   them in a private bare repository and pushes them only to the mirror.

   The version stays below 1.0 until the public API has been reviewed for
   outside use. Today's surface was written for the app and includes types only
   the app uses (`MenuBarFormat`, `WatchDayDisplay`, `ComplicationAccessibility`,
   `WatchDayCopy`) and module-level functions such as `bsToAD`. Under 0.x a
   minor release may change any of it, and the README tells consumers to pin
   to the next minor version.

3. **NepalKitCore is relicensed to MIT.** The maintainer is the core's only
   human author, and the other commit identities in its history are AI tools,
   so the change needs no one else's consent. `NepalKitCore/LICENSE` carries
   the MIT text, and the core's SPDX headers say `MIT`. The askbuddie base
   table was already MIT, and its notice is retained unchanged. The app, the
   Watch products, the scripts and the documentation stay GPL-3.0-or-later.
   The licence change grants nothing new for the calendar data:
   SOURCES.md's *Copyright scope* section still applies to it.

4. **iOS 26 is declared, and tested at every release.** The manifest declares
   `.iOS(.v26)`. `release-core.sh` runs the full core suite on macOS, an iOS
   Simulator and a watchOS Simulator, in a clone of the split, before it signs a
   tag. Running the suite in the split rather than here also proves the package
   needs nothing from the rest of this repository. When this was decided, the
   iOS suite ran on the iOS 27 Simulator, the only iOS runtime installed on the
   release machine. Its compile floor is 26 because the manifest says so.

## Consequences

- The roadmap's *Not planned* row narrows to a plugin interface. The core's API
  is now a published surface, which is the commitment that row warned about.
  0.x is how the project limits that commitment until the API has been reviewed.
- A package release is a maintainer action from the release machine, like an
  app release. No new credential exists: the pushes use the maintainer's own
  GitHub access, and no workflow can reach the mirror.
- The mirror's commits are not signed, because `git subtree split` rewrites
  them and drops the signatures. Each release tag is signed and covers the
  tree it points at. A reader verifies a release against this repository by
  rerunning the split ([release verification](../release-verification.md#verifying-a-nepalkitcore-release)).
- Changes under `NepalKitCore/` are contributed under MIT, not GPL
  (CONTRIBUTING.md, *Licensing of contributions*).
- A dataset change reaches the package's consumers only through a package
  release, so one should follow the app release that ships it. A narrowed
  supported range (ADR-0010) is a breaking change for consumers. It needs a
  minor bump under 0.x and a major bump after 1.0.

## Considered options

**A `Package.swift` at this repository's root.** Rejected. It needs no second
repository, but the package's versions would be the app's `v*` tags. An app
release with no core change would bump the library, and a breaking library
change would need an app major version. It would also make the pre-1.0 option
impossible, because the tags are already at 1.7.0.

**Move the core into its own repository and consume it remotely.** Rejected.
Calendar data changes, the app and the Watch products would land in two
repositories, and a dataset correction could no longer be reviewed in one pull
request with the app change it requires.

**Keep the core GPL.** Rejected by the maintainer. A GPL Swift package is
usable only by GPL software, which defeats the reason for publishing it.

**Release 1.0.0 with today's API.** Rejected. It would freeze names that exist
only for the app's menu bar and Watch complications.

This ADR amends ADR-0014's statement that NepalKit code is GPL-3.0-or-later,
for the core only.
