# Three independent version numbers, with Sparkle ordering on the build number

NepalKit tracks three version numbers that move independently: the **application
version** (`CFBundleShortVersionString`, human-facing, shown in About, currently
`1.3.0`), the **build number** (`CFBundleVersion`, a monotonically increasing
integer, currently `5`), and the **calendar dataset version** (currently
`2.0.0`). Git tags follow the application version.

The build number is not a display concern — it is load-bearing for updates.
Sparkle's documentation requires an incrementing, properly formatted
`CFBundleVersion` and uses it to decide which build is newer; since Sparkle 2.7
custom version comparators are deprecated in favour of an increasing numeric
build version kept disjoint from the human-facing short version. Before this
decision the project set `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION
= 1`, which meant that tagging a `0.1.0` release by changing only the marketing
version would have left the build number unchanged across two releases, and
Sparkle would have offered no update. That failure looks like a Sparkle bug and
is not one.

Keeping the two numbers disjoint also means the About panel can show a stable
human-facing version while the build number moves on fixes that users never see.
The dataset version is separate again because calendar data is a distinct
artifact with its own compatibility contract: narrowing the supported range is a
breaking change to that contract and bumps the dataset version independently of
any application release.

## The application version is semantic, and the tag is derived from it

`CFBundleShortVersionString` carries three numeric components. Git tags, the
Sparkle enclosure filename, and the Homebrew cask all derive from it —
`scripts/package-release.sh` names the enclosure `NepalKit-$VERSION.zip`, and
`scripts/verify-appcast.sh` recovers the release tag from that filename — so
there is exactly one version string to keep correct, and its shape is a release
contract rather than a formatting preference.

Three components is what makes `1.3` and `1.3.0` the same release to all three
consumers, and it is also what keeps the version disjoint from the build number
structurally: a dotted three-component string cannot be parsed as an integer at
all, so no comparator can read one as the other. Under the earlier two-component
scheme that disjointness had to be maintained separately, because `1.0` and `1`
are different strings expressing the same number.

**Releases 1.0 through 1.2 shipped two-component versions and are not
rewritten.** Their tags, feed entries and release assets stay as published:
`verify-appcast.py` fetches every enclosure URL in the feed and fails the release
gate on a 404, so retagging history would invalidate the live feed that every
installed copy polls. Semver begins at 1.3.0.

## The guards read the project file, and the appcast, not a copied constant

`NepalKitTests/BuildNumberTests.swift` asserts that the build number is a
positive integer, that the application version is three-component semver, and
that the build number has not fallen below the highest one the feed has already
offered. That last guard originally compared against a hand-maintained constant
which read `3` for several releases after build 4 had shipped as 1.2 — a guard
that silently lags a release reads as a guard while permitting the regression it
exists to prevent, so the floor is now derived from `appcast.xml`, which is the
record of what actually shipped.

## Considered Options

**Use the short version string for update ordering.** Rejected. Sparkle 2.7
deprecated custom version comparators, and ordering on a human-facing string
invites exactly the collision described above.

**One number for everything.** Rejected. The dataset version changes when
calendar data changes, which is not the same event as an application release,
and conflating them would either force dataset bumps to look like app releases
or hide real breaking data changes behind an unchanged version.

**Retag released history to semantic versions.** Rejected. `verify-appcast.py`
fetches every enclosure URL in the feed and fails the release gate when one 404s,
so moving the 1.0, 1.1 and 1.2 tags means rewriting three published URLs in the
feed that every installed copy reads, and breaking every `/releases/tag/1.2`
link, to make the tag scheme uniform across three releases nobody is installing.

**Drop the patch component for releases that are not patches.** Rejected. The
cost is a version string whose meaning depends on which release you are looking
at, in exchange for saving two characters.
