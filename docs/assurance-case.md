# Assurance case: the NepalKit macOS app

## Purpose and scope

An assurance case is a structured argument that a system is fit for a stated
purpose, with the evidence for each claim and the reasoning that connects them.
This one covers **NepalKit 1.6.0 on macOS 26.6**, the macOS app as distributed by
Developer ID and updated through Sparkle.

It does **not** cover the watchOS app, which ships from source and is under a
different evidence regime; nor the calendar data's accuracy, which is a
correctness claim argued in [SOURCES.md](../SOURCES.md); nor the maintainer's own
machine, which is out of scope by definition.

**Who wrote it and what that means.** The maintainer wrote it, reviewing their own
work. That is the case's principal weakness and it is stated here rather than
implied: an assurance case whose author has every incentive to overlook a problem
is worth less than one written by somebody else. Nothing below should be read as
an independent assessment. See finding F5 in
[docs/security-assessment.md](security-assessment.md).

## The claim

> NepalKit, as distributed, does not give a remote party a way to execute code on
> a user's Mac, does not misrepresent the date it displays, and does not leak the
> user's data — **except** that it displays one calendar year (2084 BS) that is a
> projection rather than an attested value, and it contacts one host to check for
> updates.

The exception is inside the claim on purpose. A case that quietly narrowed its
scope to avoid the exception would not be an assurance case.

## Argument

The claim splits into four sub-claims. Each depends on the one beneath it.

### 1. A remote party cannot execute code on the user's Mac

Depends on:

- **1a. The update feed is authenticated, not merely fetched.** The app refuses a
  feed with no Ed25519 signature, and the public key is in the signed binary.
  *Evidence:* `SUPublicEDKey` in `NepalKit/Info.plist`; `SUFeedRequiresSignature`
  in the same file; `InfoPlistKeysTests` reads the **built product's** plist, so
  a key the build drops cannot pass. Added in 1.4.1 — see
  [CHANGELOG.md](../CHANGELOG.md).
- **1b. Archives are signed, and the signing key is not reachable remotely.** The
  private key is in one machine's keychain and is in neither the repository nor
  CI. *Evidence:* `scripts/package-release.sh`;
  [docs/secrets-policy.md](secrets-policy.md); no `pull_request` workflow
  references a secret, and `release-tag.yml` declares `permissions: {}`.
- **1c. A release cannot be produced without the signing identity being present
  locally.** *Evidence:* `package-release.sh` fails if no Developer ID certificate
  for team `CA89X9954L` is in the keychain.

**Inference.** The only path from the network to executing code is the updater.
Every step on that path is authenticated, and the credential that authorises it
is not in GitHub. Therefore a network attacker — including one with a stolen
GitHub session — cannot cause code execution.

**Residual risk.** An Ed25519 or Sparkle verification defect; compromise of the
release machine. Both are outside what this repository can control, and both are
argued in [docs/threat-model.md](threat-model.md) as T1, T2 and T5.

### 2. The date displayed is not silently wrong

Depends on:

- **2a. Every month length traces to a pinned source.** *Evidence:*
  [SOURCES.md](../SOURCES.md); `data-sources.yml` fails the build when the
  shipped table diverges from its recorded baseline.
- **2b. 2084 BS is published as a projection.** *Evidence:* README, SOURCES.md,
  the About window, and CHANGELOG.md all say so.
- **2c. Out-of-range and invalid input produces an error state, not a plausible
  answer.** *Evidence:* `Conversion.swift` returns explicit unsupported and error
  cases; `InvalidDateTests`, `Projected2084Tests`.

**Inference.** A wrong date is possible — the dataset has documented
disagreements — but it cannot be wrong *silently* in the sense of being
indistinguishable from a correct one.

**Residual risk.** 2084 BS is wrong if the projection is wrong. That is stated in
every surface that shows it.

### 3. User data does not leave the machine

Depends on:

- **3a. There is one network call and it is to one HTTPS host.** *Evidence:*
  `NepalKit/NepalKit.entitlements` grants exactly one network entitlement, for
  the update check; no analytics SDK is depended on
  ([docs/dependencies.md](dependencies.md)).
- **3b. No credential or personal datum is stored.** *Evidence:* preferences in
  the app's own container; `no_leaked_credentials` on the badge entry.

**Inference.** "Does not leak" is bounded by "has nothing to leak and makes one
outbound request". Privacy is not a claim this project can make strongly about
itself; it is a claim about there being nothing there.

### 4. The distribution channel is not an attack surface

Depends on notarization, stapling, the hardened runtime being mandatory, and the
Homebrew cask digest being computed only after the artifact passes those checks.
*Evidence:* `scripts/package-release.sh`, `scripts/update-cask.sh`,
[docs/release-verification.md](release-verification.md).

## Evidence not available

Named because an assurance case that lists only what it has is hiding the rest.

| Missing | Consequence |
| --- | --- |
| Independent security review | The whole case is self-authored. Findings F3, F5 and F8 exist because of this |
| Dynamic analysis or fuzzing | The conversion path is argued from tests, not from adversarial input |
| 80% statement coverage | Measured 62.78%; see [docs/coverage.md](coverage.md) |
| A second maintainer | No second reviewer for any claim here |
| Pen test of the updater | The highest-consequence path is argued from code and notarization, never attacked |

## What would falsify this

Stated as conditions, because a case that cannot be broken is not a case.

1. A Sparkle or Ed25519 verification bypass. → Claim 1 fails.
2. The EdDSA private key appearing in the repository, in CI logs, or in a
   release artifact. → Claim 1b fails.
3. A month length in the shipped table that no source supports. → Claim 2 fails.
4. A network call that is not the update check. → Claim 3 fails.
5. A release signed without the hardened runtime. → Claim 4 fails.

Each is checkable by a gate or a review, which is what makes them worth
listing. Items 1, 3 and 5 are already gates; items 2 and 4 are not, and that gap
is F8 in the security assessment.
