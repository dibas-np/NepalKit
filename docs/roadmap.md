# Roadmap

What is planned, what is deliberately not, and what would change each answer.
Kept short on purpose: a roadmap that lists everything is a wish list, and one
that lists nothing is worse.

**This is not a commitment to a date.** Nothing here has a schedule, and a date
on a solo-maintained macOS app is a promise nobody can keep. What each item *is*
committed to is the condition that would let it be built.

## Where the project is

v1.6.0 ships a menu-bar date, a converter, Siri and Shortcuts support, and a
standalone Apple Watch app with four complication styles. See
[CHANGELOG.md](../CHANGELOG.md) for what has actually changed and
[docs/achievements.md](achievements.md) for what it added up to.

## Planned

### App Store distribution for the Watch app

The Watch app is currently built from source and runs on a development-signed
destination. Distribution means a signing identity, a store record, a privacy
manifest, and a review cycle.

*Blocked on:* a decision about whether the Mac app stays Developer-ID-only. The
two channels have different update models — Sparkle versus the store — and
supporting both is a permanent tax, not a one-time cost.

*Would change:* ADR-0011 (one product, one update channel) if the answer is that
both ship.

### Reducing the supported calendar range

2084 BS is a projection. Every year the range extends, the claim gets weaker.

*Blocked on:* corroboration. When a second independent source disagrees with the
shipped table for a year inside the range,
[ADR-0010](adr/0010-supported-range-narrowing.md) governs what happens next, and
narrowing is a legitimate outcome of that process rather than a failure of it.

*Would change:* ADR-0002 (dataset versioning), the About window, and SOURCES.md.

### A second maintainer

Not a feature, but the item most likely to change what this project can
guarantee. See [GOVERNANCE.md](../GOVERNANCE.md) and finding F3 in
[docs/security-assessment.md](security-assessment.md).

*Blocked on:* a person willing to do it. Several badge criteria and one real
risk — a compromised single account — are closed by this and by nothing else.

## Under consideration

- **Coverage as a gate.** The number is now measured and published; see
  [docs/coverage.md](coverage.md). Raising the floor is a separate decision from
  measuring it, and the honest reason not to rush it is that the SwiftUI layer
  cannot be covered without either UI tests or a view-logic refactor, and
  [ADR-0005](adr/0005-app-layer-test-execution.md) records why hosted UI tests
  are not available here.
- **Signing release tags.** Implemented; see
  [docs/release-verification.md](release-verification.md) for how to verify one.

## Not planned

Stated so that their absence is a decision rather than an oversight.

| Not doing | Why |
|---|---|
| Telemetry, analytics, crash reporting | Would be a second third-party dependency and the first with network egress of its own. See ADR-0012 for how the dependency budget is argued |
| A website separate from the repository | The GitHub repository is the documentation. A second site would need its own security posture and this project has no capacity for two |
| Hosting the app outside the Mac App Store for the Mac app | The Developer ID channel is signed, notarized and update-signed end to end today. Adding a store would mean maintaining two update models |
| A public API or plugin interface | The surface would be a security commitment. Not one a solo maintainer should make |

## How this document goes stale

A roadmap that is not checked is worse than none. The conditions above are the
checkable part: when a blocking condition clears, the item either moves or gets
removed, in a pull request, by someone who wrote down why. `documentation_roadmap`
on the OpenSSF badge entry is Met on the strength of this file existing and
naming its blockers — so if the blockers stop being true, this file is wrong and
so is the badge answer. That coupling is deliberate.
