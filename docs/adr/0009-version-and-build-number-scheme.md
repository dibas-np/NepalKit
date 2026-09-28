# Three independent version numbers, with Sparkle ordering on the build number

NepalKit tracks three version numbers that move independently: the **application
version** (`CFBundleShortVersionString`, human-facing, shown in About, moving
`0.1.0` → `1.0.0`), the **build number** (`CFBundleVersion`, a monotonically
increasing integer), and the **calendar dataset version** (currently `2.0.0`).
Git tags follow the application version.

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

Because a build-number regression would not surface until an update silently
stopped appearing, a test asserts that build numbers increase.

## Considered Options

**Use the short version string for update ordering.** Rejected. Sparkle 2.7
deprecated custom version comparators, and ordering on a human-facing string
invites exactly the collision described above.

**One number for everything.** Rejected. The dataset version changes when
calendar data changes, which is not the same event as an application release,
and conflating them would either force dataset bumps to look like app releases
or hide real breaking data changes behind an unchanged version.
