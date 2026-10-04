# Secrets and credentials: the policy

This document exists so that the answer to "how does NepalKit handle secrets?"
is written down in one place instead of being reconstructed from four workflow
headers. It covers what the project holds, where each thing lives, who can reach
it, how it is rotated, and what happens if one leaks.

The short version: **NepalKit has no credential that can produce a signed
release, and none of them are reachable from a pull request.** Every secret that
could sign or publish something lives on one maintainer's machine or in a single
scoped GitHub environment. That is a deliberate design property, defended
below, not a consequence of the project being small.

## 1. The inventory

Every credential this project uses, and nothing else. If something is not in
this table, it is not a credential — it is a bug in this table.

| Credential | What it can do | Where it lives | Reachable from a pull request? |
| --- | --- | --- | --- |
| Sparkle EdDSA **private** key | Sign the update feed, and sign update archives | The release machine's login keychain. Never in the repository, never in CI | **No** |
| Sparkle EdDSA **public** key | Verify updates — safe to disclose | `SUPublicEDKey` in `NepalKit/Info.plist`, committed | n/a |
| Apple Developer ID Application certificate + private key | Code-sign a distributed `.app` | The release machine's keychain | **No** |
| `notarytool` keychain profile (`NepalKit-notary`) | Submit to Apple's notary service | The release machine's keychain, created once with `xcrun notarytool store-credentials` | **No** |
| `TEAM_ID` (`CA89X9954L`) | Selects the signing identity. **Not a secret** | Supplied by the maintainer; the value is public in `docs/watch/readiness-evidence.md` | n/a |
| `HOMEBREW_TAP_DEPLOY_KEY` | Push to `dibas-np/homebrew-tap`, and nowhere else | GitHub **environment** secret `release`, not a repository secret | **No** — only the `bump-tap` job, on a `v*` tag, in that environment |

Everything else the project reads is configuration, not credential, and is
documented in [`.env.example`](../.env.example): `SPARKLE_BIN`,
`NEPAKIT_DATA_CACHE`, `NEPAKIT_TAP_DIR`, `NEPAKIT_BUILT_PLIST`. All are
optional, all have defaults, and none of them is sensitive.

`.env` is git-ignored. It exists so a maintainer can keep local paths out of
shell history, not to hold anything secret — the comment in `.env.example` says
so explicitly, so that a future contributor does not read the file's existence
as permission.

## 2. Storage rules

These are the rules. They are short because the alternatives are worse.

1. **No secret is ever committed.** Not to the repository, not to a workflow,
   not to a fixture, not "temporarily".
2. **No secret is ever passed as a command-line argument** to a tool that logs
   its own invocation. CI passes secrets through `env:` blocks, which keeps them
   out of `set -x` output and out of process listings.
3. **Signing material lives in a keychain, not in a file.** The Sparkle private
   key and the Developer ID key are in the login keychain of one machine. There
   is no `.p12`, no `.pem`, and no key file in this repository to leak, rotate,
   or accidentally attach to a bug report.
4. **CI credentials are scoped to the smallest thing that needs them.**
   `HOMEBREW_TAP_DEPLOY_KEY` is a **deploy key on the tap alone**. It cannot
   write to this repository, and it cannot sign anything.
5. **No workflow triggered by `pull_request` may reference a secret at all.**
   This is why every pull-request-triggered workflow builds with
   `CODE_SIGNING_ALLOWED=NO`: a job that cannot reach a credential cannot be
   coerced into using one, so a malicious pull request does not get to choose the
   conditions under which a secret is read.

## 3. Access control

| Actor | Can reach | Cannot reach |
| --- | --- | --- |
| The maintainer (`@dibas-np`) on the release machine | Everything, by definition — it is the only machine holding the keys | — |
| The maintainer on any other machine | Nothing. Releases are cut on one machine (ADR-0012) | All signing and notarization credentials |
| A pull-request workflow run | `GITHUB_TOKEN` scoped to `contents: read`; no environment secrets | Every credential in the table above |
| The `release` environment (tag-triggered only) | `HOMEBREW_TAP_DEPLOY_KEY` | The EdDSA key, the Developer ID key, the notary profile |
| An outside contributor | Nothing | Everything |

The `release` environment is a separate object from the repository on purpose.
An environment secret is not readable by any job that does not explicitly
declare `environment: release`, so adding a new workflow cannot accidentally
inherit the deploy key — the default is that it cannot see it.

`release-tag.yml` enforces the identity half of this in the `if:` of each job
rather than in a script inside one. GitHub evaluates `if:` before the job
exists, so a job that should not run never receives the environment it guards;
a shell check would run *inside* a job that had already been handed the deploy
key. The shell assertions in the same file reject a *malformed* tag, which is a
mistake, and the `if:` rejects an *unauthorised* one, which is not.

## 4. Rotation

| Credential | Trigger | Procedure | Blast radius if it leaks |
| --- | --- | --- | --- |
| Sparkle EdDSA private key | Suspected compromise, or routine rotation | Generate a new keypair, replace `SUPublicEDKey` in `NepalKit/Info.plist`, rebuild, cut a release, and keep the old key valid until users have had a chance to update | Attacker can sign an update that every existing install accepts. **Full compromise of every installation.** |
| Apple Developer ID certificate | Apple's revocation, expiry, or suspected compromise | Revoke in the Apple Developer portal, issue a new one, re-sign and re-notarize, cut a release | Attacker can sign malware that Gatekeeper reports as Developer ID-signed. Mitigated by notarization: a self-signed binary is not notarized, and Gatekeeper refuses it |
| `notarytool` profile | Apple's revocation, or the Apple ID's password changing | `xcrun notarytool delete-credentials NepalKit-notary`, then `store-credentials` again | Attacker can submit to the notary service under this project's identity. Does not by itself let them sign anything |
| `HOMEBREW_TAP_DEPLOY_KEY` | Suspected compromise, or contributor turnover | Delete the key in `dibas-np/homebrew-tap` → Deploy keys; generate a new one; update the `release` environment secret | Attacker can push a cask to the tap. That is a **supply-chain compromise of the Homebrew install path** — the worst outcome in this table, and the reason the key is scoped to that one repository and nothing else |

The EdDSA key is the one with no partial answer. It is also the one that
**cannot be rotated from CI**, which is the property that makes rotation an
offline, deliberate act instead of something an attacker with a stolen token
could trigger.

### Routine cadence

There is no calendar rotation. Key material for a project with one maintainer
and one release machine rotates when it is suspected, when a provider revokes
it, or when the developer-program year requires it. A fixed rotation schedule
would be a claim of process rather than a reduction in risk, and would add a
release to the calendar for no security benefit.

## 5. Detection

| Control | State | What it does |
| --- | --- | --- |
| GitHub secret scanning | **enabled** | Flags known credential patterns in the repository and in its history |
| Secret scanning push protection | **enabled** | Blocks a push that introduces a detected secret, before it reaches the branch |
| `.gitignore` | `.env`, `build/`, `DerivedData/`, `.build/`, `.swiftpm/` | Keeps local environment files and build output out of the index |
| Dependency Review | `dependency-review.yml`, a required status check | Catches a vulnerable dependency arriving via a pull request — see [dependencies.md](dependencies.md) |

Push protection is the one that matters most, because the realistic failure for
a project this size is not a compromised keychain; it is pasting a credential
that was meant to stay local into a workflow — a `HOMEBREW_TAP_DEPLOY_KEY:`
value, a `SPARKLE_BIN:` path that names the keychain, a notarization key
reference — while wiring up the release pipeline. That push does not happen.

`TEAM_ID` is the obvious counter-example and it is why this paragraph is about
*credentials*: `CA89X9954L` is printed on every signed build and is public, so
pushing it is not a leak and push protection will not stop it. It is listed here
as a non-secret precisely so nobody reads it as one.

Two honest limits:

- **Secret scanning detects patterns, not secrets.** A key stored under an
  unrecognised name, or a base64 blob that is not a known credential format, is
  not detected. The control is a backstop, not the primary defence; the primary
  defence is that nothing is ever written down.
- **Detection is not prevention.** Push protection fires on the way in. A secret
  that reaches `main` through an accepted bypass is still in the history, and
  rotation — not deletion — is the remedy. `git log` is public and permanent.

## 6. If a secret leaks

In order, and without skipping steps:

1. **Rotate first. Do not investigate first.** A leaked credential is assumed
   compromised from the moment it is known to be exposed; the investigation is
   about scope, and it happens after the attacker no longer has what they took.
   Follow the row in section 4.
2. **Revoke at the provider**, not just locally. Deleting a GitHub environment
   secret does not un-copy it; deleting a Deploy key in the tap's settings does
   un-authorize the key that was copied.
3. **Then scope it.** `git log --all -S'<fragment>'` on the repository, and the
   provider's audit log for the credential's namespace, answer "who used it".
4. **Record it.** Add what happened and what was rotated to
   [CHANGELOG.md](../CHANGELOG.md) and, if it affected users, to the release
   notes and the security advisory ([SECURITY.md](../SECURITY.md)).
5. **If users were affected, publish an advisory.** The reporting path and the
   disclosure expectations are in [SECURITY.md](../SECURITY.md); a maintainer
   credential leak that let an attacker sign an update is a vulnerability in this
   project, not a private embarrassment, and users are entitled to know which
   versions to distrust.

## Rejected alternatives

- **Move signing into CI so releases are one tag away.** Rejected, and defended
  at length in `release-tag.yml`'s header. A signing key in Actions is a
  credential reachable by anyone who can open a pull request against a workflow
  file, and it would make "a stolen repository can produce a signed NepalKit"
  true. The current arrangement makes that false.
- **Store the keys in a `.env` or a keychain-exported file in the repository.**
  Rejected: it converts "the key is in a keychain on one machine" into "the key
  is in this repository's history", which is the one outcome the whole policy
  exists to prevent.
- **Dependabot for the Sparkle pin.** It cannot read an
  `XCRemoteSwiftPackageReference`, so the entry would be inert — and an entry
  that looks like coverage is worse than the documented gap in
  [dependencies.md](dependencies.md).
- **Automated rotation on a schedule.** Rejected as process theatre; see the
  cadence note above.
