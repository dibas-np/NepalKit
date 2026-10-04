# Threat model

What could go wrong in NepalKit, who could make it happen, and what is already
standing in the way. This is the attack-surface analysis half of the project's
security work; the assessment of what was actually reviewed, and what was found,
is in [security-assessment.md](security-assessment.md).

The scope is deliberately the **shipped product plus the pipeline that produces
it**. A menu-bar calendar app has a small runtime surface and a large
distribution surface, and the second one is where the interesting threats are.

## The system, and what it actually does

NepalKit is a sandboxed, `LSUIElement` macOS menu-bar app and a standalone
watchOS app. It:

- reads a **bundled** calendar table (`NepalKitCore`), converting between Bikram
  Sambat and Gregorian dates entirely offline;
- holds user preferences in its own container;
- offers three App Intents to Siri and Shortcuts;
- performs **one** network operation: checking a Sparkle appcast over HTTPS at
  `https://dibas-np.github.io/NepalKit/appcast.xml`, and installing an update
  the user has been prompted to approve.

It has no account, no analytics, no telemetry, and holds no credentials. That
sentence is the reason the threat model is short, and it is worth stating as a
claim to be falsified rather than as an assurance: if a future change adds a
network call that is not the update check, this document is wrong and needs
rewriting.

## Assets

Ordered by what losing them would actually cost.

| # | Asset | Why it matters |
| --- | --- | --- |
| 1 | **The user's Mac** | The update path is the only route by which a remote party can cause code to execute here |
| 2 | **The EdDSA private signing key** | Whoever holds it can sign an update every existing installation accepts. Full compromise of every installation |
| 3 | **Calendar correctness** | The product's reason to exist. A wrong date is a correctness failure, not usually a security one, but see T9 |
| 4 | **The release pipeline** | A compromised pipeline ships to every user who upgrades |
| 5 | **The maintainer's GitHub account** | Write access to this repository, the tap, and the Pages site — i.e. control of the update channel |
| 6 | **The Apple Developer identity** | Signing and notarization capability |
| 7 | User preferences | Low value. No secrets are stored, by design |

## Actors

| Actor | Capability |
| --- | --- |
| **Network attacker** (on-path, or able to poison DNS/TLS for one user) | Can serve a hostile appcast; cannot forge an EdDSA signature |
| **Attacker with the maintainer's GitHub session** | Can push to `main` (via the ruleset bypass), rewrite the appcast, rewrite the Homebrew cask, read the repository. Cannot sign a release: the key is not in GitHub |
| **Attacker with the release machine** | Everything, including signing. Out of scope — that is the trusted endpoint |
| **Malicious or compromised contributor** | Can open a pull request. Cannot reach any credential, because no `pull_request` workflow references one |
| **Local unprivileged attacker** (another app, same user account) | Can read the container's preferences, tamper with the bundle on disk, and talk to the App Intents |
| **The user** | Can approve or decline an update; cannot be forced into anything |

## Trust boundaries

1. **Network → app.** The appcast. The only inbound data from a party the user
   does not control.
2. **Appcast → installed code.** The update archive. The highest-consequence
   boundary in the product: everything below it is about defending this one.
3. **Process → process (sandboxed).** Sparkle's two XPC services, reached by
   Mach-lookup exception entitlements.
4. **Outside the app → app.** Siri and Shortcuts supply date parameters; VoiceOver
   and the Watch's spoken output leave the app.
5. **Repository → user.** What a contributor, or a compromised maintainer
   account, can cause to be built, signed, and shipped.
6. **Developer machine → release.** Where signing material lives.

## Threats, and what is in the way

### T1 — A hostile appcast points an installation at a hostile archive

**Actor:** network attacker. **Boundary:** 1 and 2.

The appcast names which archive to download. Serving a rewritten one is the
cheapest attack against a Sparkle app, and it is the reason the feed itself is
signed rather than merely fetched.

**Standing:** the feed carries an EdDSA signature and NepalKit **refuses a feed
without one** — `SUFeedURL` and `SUPublicEDKey` both live in `Info.plist`, and
`InfoPlistKeysTests` reads the built product's plist rather than the project, so
a key that the build silently drops cannot pass. The archive carries its own
signature. This was added in 1.4.1, when the feed was unsigned and every download
was verified but the document naming it was not — see
[CHANGELOG.md](../CHANGELOG.md).

**Residual:** a signature *replay* — serving an older, legitimately signed
feed. Bounded: Sparkle will not offer a build the user already has.

### T2 — A hostile archive is installed

**Actor:** network attacker, or anyone who can write to the Pages site.
**Boundary:** 2.

**Standing:** Ed25519 signature over the archive, verified against a key baked
into the signed binary. The private key is in one machine's keychain and is not
in GitHub, in CI, or in the repository — see
[secrets-policy.md](secrets-policy.md). This is the single most important
property in the project.

**Residual:** an Ed25519 implementation failure, or a compromise of the release
machine. Both are outside what this repository can control.

### T3 — A hostile build reaches users through the Homebrew cask

**Actor:** attacker with the maintainer's GitHub session. **Boundary:** 5.

`brew install --cask dibas-np/tap/nepalkit` verifies a recorded digest and
nothing else. The digest is therefore the entire trust anchor on that path,
which is why `scripts/update-cask.sh` does not compute one until the downloaded
`.app` has passed `spctl -a -t execute`, `xcrun stapler validate`, and a signing
identity check — a digest over bytes no gate has vouched for would be the whole
problem.

**Standing:** the cask bump runs only on a `v*` tag pushed by `dibas-np`, gated
in the `if:` rather than in a script, behind the deployment-floor gate, with a
deploy key scoped to the tap alone. The tag is re-verified inside the job, since
a tag can move between preflight and the job holding the key.

**Residual:** full compromise of the maintainer's GitHub account yields a
rewritten cask. It does **not** yield a signed NepalKit, because signing
happens on a machine GitHub cannot reach.

### T4 — A hostile appcast is published

**Actor:** attacker with the maintainer's GitHub session. **Boundary:** 1.

`pages.yml` deploys `appcast.xml` from `main`. That makes the appcast only as
trustworthy as the repository.

**Standing:** the appcast is verified before it is deployed, and only the
`deploy` job holds `pages: write`. But an appcast is signed on the release
machine and committed, so the *signature* is what carries the trust, not the
hosting.

**Residual:** an attacker who can push to `main` can remove a release from the
feed or add a correctly-*invalid* one. They cannot forge a valid signature. The
worst case is a denial of updates, not a malicious one.

### T5 — A compromised contributor gets code merged

**Actor:** malicious or coerced contributor. **Boundary:** 5.

**Standing:** the `main` ruleset requires a pull request, blocks force-pushes and
deletion, and requires `build, test, and launch on macOS 26` to pass — a job
that builds, runs three test suites, and launches the binary. `CODEOWNERS` makes
the maintainer's review a hard requirement on the calendar data, the updater, the
entitlements, `Info.plist`, and the licence. Every action is pinned to a commit
SHA, so a compromised action cannot be swapped in silently. No `pull_request`
workflow can reach a credential. DCO is checked per commit.

**Residual — stated, not hidden:** the ruleset sets
`required_approving_review_count: 0`, because the maintainer is the only
reviewer and GitHub does not permit self-approval. The repository owner is a
bypass actor. So today a pull request is gated on **CI, CODEOWNERS, and human
judgement, not on a second pair of eyes**. For a single-maintainer project this
is the only configuration that does not lock the maintainer out of their own
repository, and it is recorded in `CONTRIBUTING.md` rather than left for a
reviewer to discover.

### T6 — A hostile CI change exfiltrates a credential

**Actor:** attacker who can merge, or who compromises a pinned action.
**Boundary:** 6.

**Standing:** no `pull_request`-triggered workflow references a secret. Every
workflow declares `permissions:` explicitly — `release-tag.yml` declares
`permissions: {}` — because omitting the block does not mean "no permissions",
it means every step gets the default token, which for a public repository is
usually read/write on contents. `release-tag.yml` checks out with
`persist-credentials: false`. Signing material is not in CI at all, so there is
nothing there to exfiltrate.

**Residual:** a merged change to a workflow *can* read the tap deploy key, since
that job legitimately has it. Bounded to the tap, on a tagged release only.

### T7 — A malicious date is spoken or displayed

**Actor:** anyone who can edit the bundled calendar table. **Boundary:** 4.

Not a memory-safety concern; a **persuasion** one. A wrong date in a menu bar is
a wrong date a user trusts, and the project already decided this matters enough
to document: the supported range narrows when evidence will not support a year.

**Standing:** `CalendarDataset.swift` and `Conversion.swift` are CODEOWNERS'd
for close reading; the data pipeline is compared against a recorded provenance
baseline on every change (`data-sources.yml`); `SOURCES.md` records every
retained correction and the evidence limit on 2084 BS, which is explicitly a
projection rather than an attested calendar. Conversion is total-function —
out-of-range and invalid dates produce an explicit unsupported/error state rather
than a plausible wrong answer.

**Residual:** the 2084 projection is a deliberate inaccuracy, published as one.

### T8 — Local tampering with the installed app

**Actor:** unprivileged local process, or malware. **Boundary:** 3.

**Standing:** the app is sandboxed with exactly one network entitlement
(`network.client`, for the update check) and two Mach-lookup exceptions for
Sparkle's own XPC services ([ADR-0008](adr/0008-app-sandbox-and-network-entitlement.md)).
Hardened runtime is required by `package-release.sh`, which fails the release if
the flag is missing. Gatekeeper and notarization cover the install.

**Residual:** another app running as the same user can replace the bundle. macOS
code signing is what makes that detectable rather than invisible, and it is not
a control this project can strengthen.

### T9 — The dataset's provenance is misrepresented

**Actor:** nobody, yet. This is a self-inflicted risk.

**Standing:** `SOURCES.md` publishes the upstream licence, the MIT notice, every
retained correction, the months where sources disagree, and the fact that 2084
BS is unverified. `verify-data-sources.py` fails the build when the shipped table
diverges from its recorded provenance. The contributor instructions are explicit
that a green comparison is not official attestation.

**Residual:** a reader who skims will take 2084 BS for attested. The README and
`SOURCES.md` both say so in bold; that is the mitigation, and it is a
documentation control rather than a technical one.

## Out of scope

- **Physical access to an unlocked Mac.** Stated as out of scope in
  [SECURITY.md](../SECURITY.md), and this document agrees.
- **Compromise of the release machine.** It is the trusted endpoint. Modelling it
  as a threat would mean modelling the project's own signing key as attacker-
  controlled, at which point the model says nothing.
- **The Apple platform, Xcode, or the notarization service.** Trusted
  infrastructure. If Apple's signing infrastructure is the attack, this project's
  answer is the same as every other Developer ID app's.
- **Denial of service by withdrawal.** If the maintainer stops releasing, users
  keep the version they have. Noted in T4 as the actual worst case there.
- **Privacy.** There is no data to leak: no account, no telemetry, no network
  call but the update check. The one user-facing input channel is Siri and
  Shortcuts date parameters, which are parsed into dates and produce an error
  state when they do not parse.

## Reviewing this document

Revisit it when any of these changes, because each one invalidates a specific
claim above rather than the document in general:

- a new network call, or a new entitlement (`NepalKit/NepalKit.entitlements` is
  called a release-contract artifact for this reason);
- a new dependency, or a change to how Sparkle is pinned
  ([dependencies.md](dependencies.md));
- a change to the ruleset, especially `required_approving_review_count` (T5);
- any move of signing or notarization off the release machine
  ([secrets-policy.md](secrets-policy.md)) — this would change T2, T3, and T6 at
  once;
- a new feature that writes outside its container, or adds an IPC surface;
- a new release channel (an App Store build is already a planned follow-up, and
  would add a second, differently-shaped distribution boundary).
