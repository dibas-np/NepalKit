# What NepalKit has achieved

A record of what shipped, in one place, because the changelog says what changed
per release and this says what it added up to. Numbers here are counted from the
repository, not from memory, and the command is given so a reader can check.

Last counted: 2026-10-04, at v1.6.0.

## The facts

| | |
| --- | --- |
| First commit | 2026-09-27 |
| Releases | 10 tags, v1.0 through v1.6.0 |
| Commits | 338 |
| Swift files | 120 |
| Test files | 54 (23 core, 24 app, 7 Watch) |
| Architecture decision records | 14 |
| Stars | 3 |
| People with commit access | 1 |

Count them yourself:

```sh
git rev-list --count HEAD
git tag | wc -l
git ls-files '*.swift' | wc -l
ls docs/adr | wc -l
gh api repos/dibas-np/NepalKit --jq .stargazers_count
gh api repos/dibas-np/NepalKit/collaborators --jq '.[].login'
```

## What it does now

- Bikram Sambat date in the menu bar, no Dock icon, macOS 26.6+
- Full Bikram Sambat and Gregorian dates with weekday, 1975-2084 BS
- Nepal Time clock at UTC+5:45 alongside local time
- Conversion in both directions, with date pickers following real month lengths
- Latin or Devanagari digits; Nepali or transliterated month and weekday names
- Three Siri and Shortcuts intents
- Standalone Apple Watch app with four complication styles
- Signed, notarized updates through Sparkle, including the update feed itself
- Offline conversion; network access only to check for updates

## What is genuinely hard-won

Not a feature list. The things that took judgment rather than typing.

**The calendar table is a provenance argument, not a constant.** Every month
length traces to a pinned upstream commit, and the fourteen local corrections
each carry an evidence status in [SOURCES.md](../SOURCES.md). 2084 BS is published
as a projection because it is one. That is a deliberate choice to be visibly
uncertain rather than quietly confident, and it is the opposite of how a date
table is usually shipped.

**The release gate broke twice, and both breakages are recorded.** A deployment
floor that reported green while the app and the release script disagreed about
what macOS version they targeted; and a hosted test runner that hung. The tests
that would have caught the first were ordered after the tests that trusted the
same wrong number, so no gate in the list could have caught it.
[ADR-0007](adr/0007-macos26-ci-release-gate.md) and
[ADR-0005](adr/0005-app-layer-test-execution.md) record what changed and why.

**The update channel is signed end to end, including the feed.** Until 1.4.1
every download was verified but the document naming the download was not, so a
tampered feed could point an installation at a different archive. Closing that
is in the changelog because it is the kind of change that matters and is easy to
miss.

**Six claims in the project's own documentation were wrong and are now fixed.**
A reviewer found them: a dependency-review gate that did not cover the
dependency it was written about, a `codesign` instruction that could not work,
and four others. The corrections are in the history rather than quietly applied.

## Who has contributed

**One person has commit access: `@dibas-np`.**

One commit of 338 carries a different author identity, `TheBoss`, which is not a
collaborator and has never had push access. Whether that is the same individual
under a second account or a genuine outside contribution is not something this
repository can establish, so it is recorded here rather than resolved.

It is recorded because it is the reason `bus_factor`, `two_person_review` and
`contributors_unassociated` are answered `Unmet` on the OpenSSF badge entry, and
because a "we have never had a contributor" claim would be false.

## What has not been achieved

Stated so the omissions are decisions.

| Not achieved | Why |
| --- | --- |
| A second maintainer | See [GOVERNANCE.md](../.github/GOVERNANCE.md) and finding F3 in [docs/security-assessment.md](security-assessment.md) |
| An independent security review | The assessment in `docs/security-assessment.md` was written by the maintainer, which is the limitation it names about itself |
| 80% statement coverage | Measured at 62.78%; see [docs/coverage.md](coverage.md) for why the SwiftUI layer makes that a refactor rather than a chore |
| Attested 2084 BS | Pending comparison with the approved Nepali Patro |
| App Store distribution | See [docs/roadmap.md](roadmap.md) |
