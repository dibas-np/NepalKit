# Dependencies: what NepalKit pulls in, and what happens when one is vulnerable

NepalKit has exactly one third-party code dependency in a shipped product, one
build-time tool, and a handful of pinned GitHub Actions. This document is the
answer to three questions a user, a contributor, or an auditor asks:

1. **What does the project depend on?** The complete inventory, because
   "we only use Sparkle" is not an inventory.
2. **How is each dependency selected, obtained, and tracked?** So a stale pin is
   a visible condition rather than an accident.
3. **What is the policy when one of them has a known vulnerability?** Stated in
   advance, because a threshold invented while a release is blocked is not a
   policy.

Sections 1–2 are descriptive and describe what the repository already does.
Section 3 is the policy, and it is binding.

## 1. The inventory

### Shipped code

| Dependency | Version | How it enters the build | Authority for the version |
| --- | --- | --- | --- |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.10.0, `exactVersion` | `XCRemoteSwiftPackageReference` in `NepalKit.xcodeproj/project.pbxproj` | the `requirement` block in `project.pbxproj` |

That is the whole list. `NepalKitCore/Package.swift` declares **no**
dependencies, and neither does the app-test harness
(`scripts/apptests/Package.swift`) beyond a relative path to `NepalKitCore`.
Everything else in the shipping app is Apple platform frameworks and this
project's own sources.

Sparkle is the update mechanism. It is not incidental: it is the code that
decides whether a downloaded archive is installed, so it is the largest single
trust dependency in the product. [ADR-0012](adr/0012-sparkle-version-pin.md)
records the decision to depend on it at all.

### Data, not code

The calendar dataset's base is
[askbuddie/bikram-sambat](https://github.com/askbuddie/bikram-sambat), pinned to
commit `d3475606084141352d3bf4472c80f9051968551a` and MIT-licensed. It is
**vendored data with its licence notice retained**, not a package-manager
dependency: `NepalKitCore/Sources/NepalKitCore/Resources/AskBuddie-LICENSE.txt`
ships inside the app bundle. Its provenance, the retained corrections, and the
provisional 2084 projection are recorded in [SOURCES.md](../SOURCES.md), which
is the authority for it. It is listed here because "dependency" is ambiguous and
this project would rather be explicit than tidy.

### Build-time and CI tooling

| Tool | Version | Pinned by | Verified how |
| --- | --- | --- | --- |
| SwiftLint | 0.65.1 | `.swiftlint-version` | sha256 of the release archive, hard-coded in `scripts/swiftlint.sh` |
| `actions/checkout` | v7.0.1 | commit SHA in each workflow, with a version comment | GitHub's own signature on the tag |
| `github/codeql-action` | v4.38.2 | commit SHA in `codeql.yml` | as above |
| `actions/upload-artifact` | v7.0.1 | commit SHA in `macos26-floor.yml` | as above |
| `actions/upload-pages-artifact` | v5.0.0 | commit SHA in `pages.yml` | as above |
| `actions/deploy-pages` | v5.0.1 | commit SHA in `pages.yml` | as above |
| `actions/dependency-review-action` | v5.0.0 | commit SHA in `dependency-review.yml` | as above |

SwiftLint is not vendored and is not on any package manager's index that this
project can pin against. `scripts/swiftlint.sh` downloads the published archive
over HTTPS and **refuses to install it unless the sha256 matches** a checksum
recorded in the script. It also passes `--proto '=https' --tlsv1.2` and treats a
scheme downgrade as fatal, because `-L` will follow a redirect to whatever
scheme the response names and a downgraded fetch would still produce bytes for
the checksum to bless.

### Deliberately absent

- **No `cocoapods`, `carthage`, or a vendored third-party source tree.** Every
  line of non-Apple code in the shipping app is traceable to a pinned upstream
  revision.
- **No analytics, telemetry, or crash-reporting SDK.** It would be the second
  third-party dependency and the first one with network egress of its own.
- **No `swift` ecosystem entry in `.github/dependabot.yml`.** Dependabot's Swift
  support reads `Package.swift` and `Package.resolved`; it does not read an
  `XCRemoteSwiftPackageReference` in an Xcode project file, which is where this
  project's only real dependency is pinned. An entry would open pull requests
  that could not change the pin, so the staleness of Sparkle is covered by the
  scheduled check in section 2 instead. This is a real coverage gap and is
  recorded as one in section 3.

## 2. How each is selected, obtained, and tracked

### Selection

Sparkle was chosen for the updater rather than hand-rolling one. The reasoning
is in [ADR-0012](adr/0012-sparkle-version-pin.md); the short form is that a
hand-written updater is a remote-code-execution surface with no reviewer
outside this repository, and Sparkle's EdDSA update authentication is a
reviewed implementation of exactly that check.

The version is pinned as `exactVersion`, not a range. This is the project's
single most consequential dependency decision and it is deliberate: an updater
that silently accepts a new minor version is an updater whose behaviour can
change without a review of this repository. `exactVersion` means a new Sparkle
reaches a user only through a pull request against this repository.

### Obtaining

SwiftPM resolves Sparkle from the `XCRemoteSwiftPackageReference` in
`project.pbxproj`. A lockfile is committed at
`NepalKit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

**That lockfile is committed but is not the authority for the pin, and this is
not an oversight.** An Xcode 27 build runs
`-resolvePackageDependencies`, resolves correctly, and then *relocates the
lockfile out of* `project.xcworkspace/xcshareddata/swiftpm/` entirely, leaving a
tracked-file deletion in the working tree. A maintainer on Xcode 27 would
otherwise be prompted to commit that deletion on an unrelated change. The pin
that actually governs resolution is the `exactVersion` requirement above, which
is why the freshness check in section 2 reads `project.pbxproj` and
`package-release.sh` verifies the built product rather than trusting
`Package.resolved`.

The correctness of that arrangement was tested rather than assumed: resolving
with the lockfile absent still produces 2.10.0.

### Tracking

| What | Mechanism | Cadence | Fails how |
| --- | --- | --- | --- |
| GitHub Actions versions | Dependabot (`github-actions` ecosystem, `/`, weekly) | weekly | opens a PR; nothing merges itself |
| Sparkle pin freshness | `sparkle-pin-freshness` job in `data-sources.yml` | monthly (`cron: "23 5 2 * *"`) and on demand | exits 1 with a notice that ADR-0012 owns the bump decision |
| Known vulnerabilities in Actions | Dependabot security updates (repository setting) | on advisory publication | opens a PR |
| Known vulnerabilities in Sparkle | **manual** — see section 3 | — | nothing automated; this is the gap |

The monthly cron for Sparkle is not a staleness check in the usual sense. The
pinned sources are immutable, so a monthly run mostly re-confirms nothing moved;
what it actually catches is a **new upstream release going unnoticed**, because
the job compares the pin against the latest published Sparkle release and fails
while they differ. The failure is deliberately a red run with a notice rather
than a silent bump: ADR-0012 owns the decision to move the pin, and a bot that
moves it would take that decision away.

### Vulnerabilities in the release pipeline itself

`release-tag.yml` reaches one credential, a **deploy key scoped to write access
on `dibas-np/homebrew-tap` alone**. It cannot write to this repository, and it
is not a signing credential. The EdDSA private key and the Apple notarization
credentials are not in CI at all — see
[secrets-policy.md](secrets-policy.md) for why that is a security property
rather than a limitation.

## 3. Policy for known vulnerabilities

### What "known" means here

A vulnerability is *known to this project* when any of the following is true:

- GitHub publishes a security advisory affecting a pinned dependency, or
  Dependabot opens a pull request for one.
- A CVE or GHSA affecting a pinned dependency is published anywhere the
  maintainer sees it. This project does not claim to poll an advisory feed for
  the Sparkle pin; see the gap below.
- Upstream publishes a fix for a defect that affects a shipped code path here.

### Remediation thresholds (binding)

| Severity | Effect on NepalKit | Remediation window |
| --- | --- | --- |
| Critical — remote code execution, or an update-path bypass | Release-blocking. The project does not ship while the finding stands. | Fix or remove the dependency before the next release; if no fix exists, remove the dependency. |
| High — sandbox escape, privilege gain, or a signature/trust check that can be defeated | Release-blocking for a tagged release. | 7 days, or withdraw the affected release. |
| Medium — information disclosure or a denial of service reachable by an unprivileged local user | Fix in the ordinary course. | 30 days. |
| Low | Fix when convenient. | Next release that touches the dependency. |

Two rules override the table:

- **The update path is never exempt.** A finding in the code that fetches and
  installs updates is Critical regardless of how the CVSS vector reads. The
  reasoning is in [threat-model.md](threat-model.md): that code is the only
  place where a remote party can cause code to run on a user's Mac.
- **A finding with no upstream fix is resolved by removal, not by acceptance.**
  This project has one third-party code dependency. Removing it is a known,
  bounded cost — [ADR-0012](adr/0012-sparkle-version-pin.md) records what
  replacing the updater would involve — which is why "we will wait for upstream"
  is not an available answer here.

### Before any release

Software composition analysis findings are addressed **before a release is
cut**, not after:

1. **On every pull request**, `dependency-review.yml` runs
   `actions/dependency-review-action` against the dependency graph and fails the
   pull request if the change introduces a dependency with a known
   vulnerability. It is a **required status check** on `main`, so it cannot be
   merged around. Findings are visible to every contributor in the pull request
   itself, which is where a reviewer can act on them.
2. **On `main`, before tagging**, the `sparkle-pin-freshness` job has to be
   green, so the release tag names a pin that was current when it was cut.
3. **`release-tag.yml`'s preflight** refuses any tag whose commit is not a
   GitHub-verified commit on `main`. A vulnerable tree that reached a tag by
   accident is caught here rather than shipped.

There is no step that runs an SCA tool against the *packaged* artifact, and that
is a known limitation rather than a decision: a macOS `.app`'s dependency set is
its embedded frameworks, and the only third-party one is Sparkle, which
`package-release.sh` already resolves from the same pinned `project.pbxproj`
requirement the review job reads. Scanning the artifact would re-derive a
smaller answer from more moving parts.

### The gap, stated plainly

**Dependabot cannot see this project's one real dependency.** Its Swift
ecosystem reads `Package.swift` and `Package.resolved`; the pin lives in
`project.pbxproj`. Dependabot security updates therefore cover the
`github-actions` ecosystem and nothing else.

The consequence is specific and worth stating rather than leaving implied: if a
vulnerability is announced in Sparkle, **nothing in this repository's automation
will notice.** The maintainer learns about it by reading an advisory, and the
monthly freshness job will not report it — that job compares *versions*, not
*vulnerabilities*, and a pinned vulnerable version is by definition current.

Closing it needs a tool that can be pointed at a pinned version explicitly. That
is not wired up yet, and until it is, the mitigation is the threshold table
above plus the fact that the dependency surface is one package.

## Rejected alternatives

- **Vendor Sparkle.** Removes the dependency-graph blind spot and makes the
  update-path code reviewable in-tree. Rejected because it makes this
  repository responsible for a security-critical subsystem nobody here can
  review as deeply as upstream, and because an `exactVersion` pin already gives
  the property vendoring would have been for.
- **Let Dependabot manage the Sparkle version.** It cannot read the pin, so the
  entry would be inert. An inert entry that looks like coverage is worse than
  the documented gap above.
- **Put signing credentials in CI so releases are automated.** Rejected
  explicitly in `release-tag.yml`'s header: it would trade the property that a
  stolen repository cannot produce a signed NepalKit for a convenience nobody
  asked for. [secrets-policy.md](secrets-policy.md) records the reasoning.
- **Use version ranges instead of `exactVersion`.** A range means a user's
  updater can install code this repository never reviewed, with no pull request
  and no changelog entry. For an updater that is the whole attack surface.
