# Security assessment

What was examined, what was found, and what the standing policy is for the tools
that find things automatically.

This is the assessment half of the project's security work. The attack-surface
analysis it draws on is in [threat-model.md](threat-model.md); the credential
inventory is in [secrets-policy.md](secrets-policy.md); the dependency story is
in [dependencies.md](dependencies.md).

**Date of last assessment: 2026-10-04.** Covers v1.6.0.

## Method, and its limits

The assessment was a **structured review of this repository by its maintainer**,
not an independent audit. Concretely, it consisted of:

1. Enumerating the runtime attack surface from the shipped entitlements, the
   `Info.plist`, and the app's own network calls.
2. Reviewing the update path end to end — feed, signature, archive, install — and
   the distribution path end to end — DMG, notarization, cask digest.
3. Reviewing every CI workflow for what credential it can reach and what it does
   with untrusted input.
4. Running CodeQL over the Swift, Python, and Actions sources.
5. Reviewing the third-party dependency surface (one package) and the calendar
   data's provenance.

**What this is not.** It is not a penetration test, it is not an independent
review, and a maintainer assessing their own project has a blind spot by
construction: the assumptions they did not know they were making. The most
valuable thing a third party could do here is attack the claims in
[threat-model.md](threat-model.md) directly, because those are the specific
assertions this project would want falsified.

No paid third-party assessment has been performed. For a project with one
maintainer and no server, that is a defensible allocation of a very small
security budget, and it is recorded here rather than left implied.

## Findings

Ranked by realistic impact on this project, not by scanner severity. "Residual
risk" is what remains after the mitigation, not whether the mitigation is
perfect.

### F1 — The update path is the whole attack surface, and it is defended

**Impact if unmitigated:** remote code execution on every user's Mac, delivered
by the app itself.

**State: mitigated, with the mitigation verified in tests.** The appcast is
EdDSA-signed and refused when unsigned; archives are signed and verified against
a key in the signed binary; the private key lives in one machine's keychain and
is unreachable from CI or GitHub. `InfoPlistKeysTests` reads the **built
product's** `Info.plist` rather than the project's, because a key the build
discards cannot be caught by reading the source — and a test that skips still
reports as passing, which would leave both keys unguarded while the job stayed
green.

**Residual risk:** a signature-verification defect in Sparkle itself, or
compromise of the release machine. Neither is controllable from here. This is
the reason Sparkle is pinned to an exact version rather than a range.

### F2 — No pull-request workflow can reach a credential

**Impact if unmitigated:** a contributor's pull request reads the tap deploy key
or a signing key.

**State: mitigated by construction.** No `pull_request`-triggered workflow
references any secret; every pull-request build runs with
`CODE_SIGNING_ALLOWED=NO`; every workflow declares `permissions:` explicitly,
and `release-tag.yml` declares `permissions: {}`. The deploy key is scoped to
`dibas-np/homebrew-tap` alone.

**Residual risk:** a *merged* workflow change can reach the tap key on a tagged
release. Bounded to one repository that is not the product.

### F3 — The repository owner is a ruleset bypass actor, and there are zero required approvals

**Impact if unmitigated:** a compromised maintainer session pushes unreviewed
code straight to `main` and on to a signed release.

**State: partially mitigated, and this is the most significant open item.**
The `main` ruleset requires a pull request, blocks force-pushes and deletion,
and requires the deployment-floor gate to pass — but sets
`required_approving_review_count: 0` and lists the repository owner as
`bypass_mode: always`.

That is a deliberate trade, not an oversight. GitHub does not permit an author to
approve their own pull request, so requiring one approval on a single-maintainer
repository either locks the maintainer out or invites them to approve their own
work, which is worse. The consequence to state plainly: **today, nothing about
this repository requires a second human to look at a change.** What stands
between a pull request and `main` is CI, CODEOWNERS, and the maintainer's own
judgement.

**Residual risk:** account compromise of `@dibas-np` is a full compromise of the
distribution channel. Mitigations that do survive it: commit signing is verified
in the release preflight, releases are cut by hand on a separate machine, and the
EdDSA key is not in GitHub.

**How this would be closed:** require one approving review from a named
non-author collaborator, and add a second maintainer. Both are blocked on the
project having a second person, which is a resourcing fact rather than a
technical one. Recorded in [threat-model.md](threat-model.md) T5.

### F4 — Dependabot cannot see the project's only real dependency

**Impact if unmitigated:** a vulnerability announced in Sparkle is noticed by
nobody, indefinitely.

**State: known gap, documented.** Dependabot's Swift ecosystem reads
`Package.swift` and `Package.resolved`; the pin is an
`XCRemoteSwiftPackageReference` in `project.pbxproj`. The monthly freshness job
compares *versions*, not *vulnerabilities*, so a pinned vulnerable version
reports as current.

**Residual risk:** bounded by the surface being one package, which is why the
remediation thresholds in [dependencies.md](dependencies.md) are short and why
"wait for upstream" is explicitly not an available answer.

**How this would be closed:** point an SCA tool at the pinned version
explicitly. Not yet done.

### F5 — No second pair of eyes on the release machine

**Impact if unmitigated:** a compromised release machine produces a signed,
notarized, malicious build that every installation trusts.

**State: accepted, by design.** Signing happens on one maintainer's machine
because that is where the key is. The alternative — keys in CI — was rejected for
the reason in F2.

**Residual risk:** this is the project's accepted maximum risk. It is mitigated by
the keychain (no key file exists to exfiltrate), by notarization (a
self-signed binary is not notarized and Gatekeeper refuses it), and by the
fresh-Mac install procedure that runs before publication.

### F6 — 2084 BS is a projection, published as one

**Impact if unmitigated:** a user treats an unverified calendar year as attested
and makes a decision on it.

**State: mitigated by disclosure, not by correction.** The README, `SOURCES.md`,
the About window, and `CHANGELOG.md` each say 2084 BS is NepalKit's own
projection pending comparison with the approved Nepali Patro. The provenance
comparison runs in CI and fails when the shipped table diverges from its recorded
baseline.

**Residual risk:** a reader who skims. Documentation is the only available
control here.

### F7 — Speech and display are separate channels, and both are reachable from outside

**Impact if unmitigated:** a malformed or extreme date produces garbled or
misleading speech, or a VoiceOver label that omits the important half of the
date.

**State: mitigated and tested.** Spoken output uses Latin digits and
transliterated month names because Devanagari digits are not reliably
pronounced; the spoken form is a separate code path from the visual one rather
than a formatting flag; conversion returns an explicit unsupported or error state
instead of a plausible wrong answer; accessibility labels are covered by tests.

### F8 — A CodeQL alert does not block a merge

**Impact if unmitigated:** a pull request introduces an `error`-severity
finding, CI is green because the analysis *ran*, and the change lands. The
finding sits in the Security tab until someone looks.

**State: known gap, and it is the enforcement half of F3's problem.** The
`Analyze (swift)`, `Analyze (python)` and `Analyze (actions)` checks are required
status checks, so the analysis cannot be skipped. The `main` ruleset carries no
`Require code scanning results` rule, so nothing blocks on an alert. The
thresholds in this document are therefore a policy with no gate behind it.

**Residual risk:** bounded by CODEOWNERS — the updater, the entitlements,
`Info.plist` and the calendar engine all require the maintainer's review, and
the documents that encode this policy do too. It is not bounded for a file
nobody claimed.

**How this would be closed:** add the `code_scanning` rule to the `main` ruleset
with an `error` alert threshold. That is one ruleset change and no workflow
change, and it is the same class of decision as the required-status-check list
already in `CONTRIBUTING.md` — so it belongs to the maintainer, not to a
documentation pull request.

### Things looked for and not found

- **No hard-coded credentials.** No key, token, or password in any tracked file.
  Confirmed by GitHub secret scanning over the full history, not just the tip.
- **No `http://` endpoint** in any official channel. The only plain-HTTP strings
  in the repository are the Apple plist DTD and the Sparkle XML namespace URI,
  neither of which is fetched.
- **No network call other than the update check.** Confirmed against the
  entitlements: one `network.client` entitlement, and its only consumer is
  Sparkle.
- **No force-unwrapped optional, no `try!` in a path reachable with attacker
  input.** The coding standard forbids force-unwraps except where non-nil is known
  at the call site, and the input that reaches conversion comes from Siri and
  Shortcuts.
- **No unreviewable binary in version control.** The only non-text tracked files
  are SVG sources and PNG screenshots.
- **No build output tracked.** `.gitignore` covers `build/`, `DerivedData/`,
  `.build/`, `.swiftpm/`.

## Static analysis: standing policy

CodeQL runs on every push to `main`, every pull request to `main`, weekly on a
schedule, and on demand — across Swift, Python, and Actions
(`.github/workflows/codeql.yml`). Its three `Analyze (*)` checks are **required
status checks** on `main`, so the analysis cannot be skipped or left unrun on
the way to `main`.

**What that does not do is block on an alert.** The `main` ruleset requires the
*checks*; it carries no `Require code scanning results` rule, so a new
`error`-severity finding surfaces in the Security tab and **does not by itself
prevent a merge**. Verified against the live ruleset, whose rule types are
exactly `deletion`, `non_fast_forward`, `pull_request` and
`required_status_checks`.

That is the difference between "the analysis ran" and "the finding was acted
on", and only the first is enforced. Closing the second means adding the
`code_scanning` rule with an alert threshold — recorded as F8.

Two properties of that workflow are deliberate and worth not undoing:

- **The Swift leg builds with tests.** The app scheme does not compile
  `NepalKitCore`'s test target, where the calendar conversion lives, so a single
  `xcodebuild` would leave roughly half the Swift source unextracted and the
  analysis would silently cover less than it appears to. There are two traced
  builds for this reason.
- **The Swift leg runs on the floor toolchain.** Analysing on a later macOS
  release would say nothing about whether the deployment-floor claim holds.

### Remediation thresholds (binding)

| CodeQL severity / class | Remediation window |
| --- | --- |
| Any finding in the update path, the entitlements, or `Info.plist` | Before the next release. These files are CODEOWNERS'd and are release-contract artifacts |
| `error` | 7 days |
| `warning` | 30 days |
| `note` / `recommendation` | Next release that touches the file |

A finding is not suppressed to make a gate green. If a finding is a true
positive that cannot be fixed on that timeline, the honest options are to fix it,
or to record why it is not exploitable in this project — in the pull request,
where the reasoning is reviewable. There is no `.github/codeql/codeql-config.yml`
allowlist, and adding one to clear a red build is the outcome this policy exists
to prevent.

### What "the gate is green" does and does not mean

It means CodeQL's queries found nothing above the configured severity on the
analyzed sources. It does not mean the code is free of defects: CodeQL reasons
about data flow, and the interesting failures in this project are
trust-boundary failures — a key in the wrong place, a check on the wrong side of
a boundary — which no dataflow query can see. Those are what this document and
[threat-model.md](threat-model.md) are for.

## Reopening this assessment

Re-run it, rather than re-reading it, when any of these changes:

- a new dependency, or a change to how Sparkle is pinned;
- a new network call or entitlement;
- any change to the ruleset's bypass actors or approval count (F3);
- a new release channel, including the planned App Store distribution;
- a security incident, or a new vulnerability in Sparkle (F4);
- a move of signing or notarization off the release machine (F5).

Record what was reviewed and what changed here, with the date, the same way this
one records it.
