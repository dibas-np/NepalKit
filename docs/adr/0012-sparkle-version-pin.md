# Sparkle 2.10.0, pinned clear of CVE-2026-47122

**Part of ticket 07. The pinned version is a release-contract item: it is what
ships, and it is what the security position rests on.**

NepalKit uses Sparkle for in-application updates. The version is pinned
deliberately rather than tracked, because Sparkle's own releases have repeatedly
carried security fixes and "whatever is newest at integration time" is not a
position anyone can defend later.

**Chosen: Sparkle 2.9.6** (released 17 August 2026), the current release.

**Bumped to 2.10.0 on 2026-09-30** (released 13 September 2026), the current
release — the freshness check below closing its first loop, deliberately by
decision rather than automatically. 2.10.0's changes sit on paths this app now
exercises: release-notes and signed-feed diagnostics, an appcast length
fallback when a server reports no content size, binary-delta and
temporary-file hardening, and a fix for first updates to bundles with
irregular extensions. Its macOS 12 deployment floor sits far below this app's,
and the CocoaPods support it drops was never part of this SPM-only
integration. The pin stays `exactVersion`; the resolved revision is checked
against the upstream tag (`eef1a539…`).

## The advisory this decision is about

CVE-2026-47122 / GHSA-g3hp-f6mg-559v, *AppInstaller post-stage-1 XPC listener
accepts unvalidated connections, allowing spoofed appcast item data injection.*
Published 18 May 2026, reviewed 29 May 2026, moderate severity.

`AppInstaller.m`'s `shouldAcceptNewConnection:` only enforced
`SUCodeSigningVerifier validateConnection:` before stage 1 completed. After
`_performedStage1Installation = YES`, new connections to the registered
`-spki` Mach service were accepted from any local process with no team-ID or
code-signing check. A local process could then inject a forged `SUAppcastItem` —
arbitrary name, version, and "critical" flag — which the progress agent
rebroadcast on `-spks`, so other Sparkle-aware apps would display attacker-chosen
release notes as authoritative installation state.

**Scope of impact: UI spoofing of installation metadata only.** The advisory is
explicit that the integrity of the installed code is unaffected — the bundle moved
into place is the legitimate, signature-validated update from stage 1. It is not
a code-execution or signature-bypass issue.

**Fixed in 2.9.2** (released 17 May 2026), whose changelog carries the matching
fix: *"Enforce connection to installer to be validated before receiving appcast
item data (#2876, #2877)"*. The affected range is `<= 2.9.1`. The fix shipped two
days before the advisory was published, so the disclosure ordering is expected
rather than a sign the fix is absent.

2.9.6 is four releases clear of the fix and also carries the security work
landed since: the 2.9.2 and 2.9.5 symlink-hardening fixes, and in 2.9.6 a local
privilege-escalation fix for processes running as root, a hardened installer
archive move, and *reject package-based installs when signature validation
failed*.

## Why not an affected version

A moderate-severity UI-spoofing bug with a fix available is not a reason to
accept it. The attack requires a local process and a tight timing window, and it
cannot substitute code — but "local, narrow, metadata-only" describes the
exploitability of a great many vulnerabilities that turned out to be worse than
described, and there is no compensating benefit to shipping a known-vulnerable
update framework when a fixed version costs nothing.

Earlier history is why this is checked at all rather than assumed: Sparkle 2.6.4
fixed an issue allowing an attacker to replace a signed update with another
payload, bypassing its (Ed)DSA checks, and 2.7.3 fixed local privilege
escalation through the Downloader and Installer XPC services.

## Relationship to the other decisions

**No Downloader XPC service** (ADR-0008). The app takes
`com.apple.security.network.client` plus the Mach-lookup exceptions for its own
`-spks` and `-spki` services. That is also what keeps the CVE-2026-47122 surface
as small as the framework allows: the vulnerable listener is the installer's
`-spki` service, which this app necessarily registers, so the mitigation is the
fixed version rather than avoiding the code path.

**Build-number ordering** (ADR-0009). Sparkle orders on `CFBundleVersion` and
requires it to be a properly formatted, increasing integer. Custom comparators
have been deprecated since 2.7 in favour of a numeric build version kept disjoint
from the human-facing short version.

## Consequence for the signing key

Sparkle's EdDSA private key is the one unrecoverable artifact in this release
plan: lose it and no installed copy ever updates again. It is generated, backed
up in at least two independent places, and the backup is verified to restore
before the first distributed build. It is never committed. The pinned version
above does not change that dependency — it is the same key contract in 2.9.6 as
in any other 2.x release.

## The signing key is a release-time secret, never a build-time one

The architecture is arranged so the EdDSA **private** key is never needed to
build the application at all. Only the **public** key is compiled in, and only
the public key belongs in the repository.

| Artifact | Needed to | Lives where |
| --- | --- | --- |
| Public key | build and ship the app | repository / build settings |
| Private key | sign a release artifact, generate the appcast | release machine and CI secret store only |

So the private key is required at exactly one moment — producing or verifying a
signed update — and never during development, never in the app target, and never
in the working tree. `Scripts` for signing run as a separate step from the app
build for the same reason.

This is what makes the custody sequence safe to run late. Until a feed and a key
exist, the app can be built, tested, and run with a network entitlement that is
never exercised, and the only thing missing is a configuration value. Nothing
has to be undone or re-signed if key generation is delayed, because no shipped
artifact has ever referenced a key.

The Settings update section is written against a `UpdateServicing` protocol, so
the model's behaviour is covered by tests that need neither a framework, a
network, a feed, nor a key — the same arrangement as `LoginItemServicing`
behind `LoginItemModel`. The Sparkle-backed implementation is the only file that
imports Sparkle, and it is excluded from the app-test harness for the same
reason `@main` is.

## The public key reached the build only after the first one was discarded

Worth recording as a process finding, because the failure was silent and the
build was green.

`INFOPLIST_KEY_SUPublicEDKey` was set in the project. **The build accepted it,
reported success, and produced an app with no `SUPublicEDKey` in it at all.**
`INFOPLIST_KEY_*` honours only a fixed allowlist of Apple-known names; a name
outside it is discarded with no warning and no error. An app shipped in that
state cannot verify a single update, and the only evidence anything was wrong was
a successful build.

This is the second time this project's own build has silently swallowed a
setting — the repository URL in ticket 06 did the same. The generalisation is the
useful part: **for a value that must appear in the product, a green build is not
evidence. Read the product.**

So the key now lives in `NepalKit/Info.plist`, wired through `INFOPLIST_FILE`
alongside the generated plist rather than replacing it, and
`InfoPlistKeysTests` reads the **built** `Info.plist` — not the project settings —
to assert:

- `SUPublicEDKey` is present and equals the committed value;
- the generated keys still survive the merge (`LSUIElement`, bundle identifier,
  both version numbers), because if that merge ever stopped happening NepalKit
  would silently become a Dock app — the most visible regression available to
  this change, and equally invisible to a green build;
- `SUFeedURL` is present, and its shape is pinned as well as its value: HTTPS,
  absolute, and served from this repository's own Pages host. It was deliberately
  absent until the first feed was published and was added when the feed appeared;
  pinning it is deliberate, because a feed URL that moves strands every
  installed copy at once.

Both of the first two were verified to fail when injected, with messages that
name the consequence rather than the assertion.

## Custody as actually configured

Recorded so nobody has to infer it. The keypair was generated on 28 September
2026 and the public half is in `NepalKit/Info.plist` (see the discarded-
setting note above).

The private key is held in the login keychain, with an encrypted iCloud copy as
the off-machine backup. **No restore has been verified yet** — a backup that has
not been restored from is a hope, not a backup.

One residual risk, stated rather than glossed: on Apple platforms the keychain
syncs through iCloud, so the keychain copy and the iCloud copy may share a single
failure domain — an Apple account loss, reset, or lockout would take both
together. That is the specific case the original custody plan ruled out by
requiring an offline copy "not merely another copy synchronized through the same
cloud account".

The gap is narrow and cheap to close: an Ed25519 private key is 32 bytes, about
64 hex characters, so a printed copy in a physical location is fully independent
of Apple, of any cloud account, and of this machine. Worth doing before the first
signed artifact, and worth restoring *from* rather than merely re-reading.

### This is now the top open risk in the project

Raised to its own heading on 2026-09-29, after 1.0 and 1.1 shipped signed. The
reason it matters more than it did: **two releases are now signed with this key**,
and the moment it is unrecoverable, every existing install stops receiving
updates and no new version can be published. Before 1.0 this was a
housekeeping item; it is now the single failure that ends distribution.

Concretely outstanding:

- [ ] A copy exists outside Apple's cloud, ideally printed and stored physically
- [ ] A restore has been *performed* and a signature produced from the restored
      material, verified against the public key in `NepalKit/Info.plist`

The second matters more than the first. A backup that has never been restored
from is indistinguishable from no backup until the moment it is needed, and
"the file looks right" is not a restore.

The public half is not the risk and needs no custody: it is committed in
`NepalKit/Info.plist`, pinned by `InfoPlistKeysTests`, and a lost private half is
unrecoverable only because signing is asymmetric. A user who loses the key can
still install any release that already exists.

## The feed is served from this repository

`https://dibas-np.github.io/NepalKit/appcast.xml` — GitHub Pages, over HTTPS as
Sparkle requires.

Chosen over `releases/latest/download/appcast.xml`, which is also a stable URL.
Pages keeps the appcast in version control beside the code and the signing key,
where a release step can regenerate it, instead of requiring an asset to be
re-attached to every release by hand and kept in step with the artifacts. The
appcast is part of the conversion contract with users — it is what every
installed copy reads — so it belongs under review with everything else.

The URL is pinned by a test, because it is the one value here that cannot move
without breaking updates for every installation at once.

**Preconditions when this was written, none of which held yet.** At the time of
this decision the repository was public and reachable but **empty** — no
branches, no commits, no releases, and Pages not enabled, so every local commit
existed only on the author's machine, and the feed URL was a declaration of
intent rather than an address. A check against it returned "could not check"
rather than a version, which the update model reported honestly rather than as
up to date.

**All of them now hold.** Corrected on 2026-09-30, when the feed had been
published for three releases: `appcast.xml` is committed at the repository root
and carries 1.1, 1.2 and 1.3.0, and Pages serves the URL above. The history is
kept because the precondition is why the URL was pinned by a test rather than
merely written down — a value nothing checks is a value that moves.

**Sign the appcast, not only the archive.** A signed archive proves the download
was not tampered with in transit; a signed appcast additionally proves the *feed*
did not lie about what the update is. Given this framework's recent history — 2.6.4
allowed a signed update to be replaced with another payload, bypassing its
(Ed)DSA checks — signing the feed as well is the difference between trusting the
transport and not having to trust the publisher's account.

**The tool is `sign_update`, not `generate_appcast`.** An earlier version of this
paragraph named `generate_appcast`, which was wrong: it writes items and signs
*archives*, and has no option to sign the feed. `sign_update` takes the feed
itself and appends a block to it:

    <!-- sparkle-signatures:
    edSignature: <base64 Ed25519 signature>
    length: <byte count of the signed content>
    -->

The signature covers every byte of the file *before* that block — the channel
element, every item, every description — not the channel element on its own.
There is no `sparkle:dsaSignature` attribute in Sparkle 2.9.6: its DSA fields are
legacy support for signing archives, and `SUAppcastDriver` passes nil for the
feed. This was read out of `SPUExtractSignedFeed.m` and then reproduced against
real `sign_update` output, rather than reasoned about, because a verifier that
guesses the canonical form rejects valid feeds and one that only tests its own
signatures looks green while being wrong.

It signs exact bytes, so it has to be the last step of a release: the notes
injection in `verify-appcast.sh` rewrites the feed, and anything signed before it
is invalidated.

`scripts/verify-appcast.py` now **requires** the block and verifies it against
the same `SUPublicEDKey` the archives use — no private key, so it runs in CI
like every other check here. When that gate landed the committed feed still
failed it: it carried three `sparkle:edSignature` values and no feed signature,
and no gate in this repository could see that before. Re-signing it means
producing a signature with the private key, which is a keychain operation for a
maintainer and deliberately not something a commit can do.

**The committed feed is now signed** (`f7de4d0`), and the check passes.

### The client requires the signature, and that depends on the feed being signed

Two controls, not one. `scripts/verify-appcast.py` is the **producer** half: it
fails the build when the published feed carries no signature. `SURequireSignedFeed`
in `NepalKit/Info.plist` is the **consumer** half: it makes Sparkle *refuse* a
feed with no signature rather than read it unauthenticated, and it is now `true`
in the shipped app, asserted against the built product by
`InfoPlistKeysTests.theSignedFeedIsRequiredInTheBuiltProduct`.

`SUPublicEDKey` alone did not give this. It made the app *able* to verify a
signature without making it *require* one, so an attacker who can rewrite the
feed in transit need not forge anything — deleting the `sparkle-signatures`
block was enough, and the app accepted the result. A signature nobody requires
is a comment.

**The dependency runs one way, and it is a real operational hazard.** Setting
`SURequireSignedFeed` while the published feed is unsigned does not weaken
anything; it stops updates entirely, because Sparkle rejects every fetch. That
is why the feed was signed *before* the key was set. The ordering is not
cosmetic: this key is safe only because the feed is signed, so any future
release that republishes the feed must sign it again or users on the current
release cannot update.

### `SURequireSignedFeed` also requires `SUVerifyUpdateBeforeExtraction`

This was found in the field, not on paper. Sparkle documents
`SURequireSignedFeed` as *"also requires enabling `SUVerifyUpdateBeforeExtraction`
as a prerequisite"*, and it enforces that: with the second key off, the updater
refuses to check at all and reports

> For security reasons, SUVerifyUpdateBeforeExtraction needs to also be enabled
> if SURequireSignedFeed is enabled for NepalKit.

Plan 038 set the first key without the second, so the app shipped unable to
update — the strongest possible failure of the control, and invisible to every
gate here, because both keys are booleans in a hand-authored plist and no test
asserted the pair. `SUVerifyUpdateBeforeExtraction` is now `true` in the shipped
app, asserted the same way by
`InfoPlistKeysTests.updatesAreVerifiedBeforeExtractionInTheBuiltProduct`.

**The lesson is about how the two relate, not about the second key.** They are
one decision: strictness is not dialable per-stage. Sparkle refuses to operate
unless the app verifies the archive *before* unpacking it, so there is no
configuration in which the feed signature is demanded and the archive is not.
Any future change to either key must change both, and the test pair is what makes
that visible.

**The tradeoff both keys carry is the key-custody one, and it is still open.**
Sparkle's documentation for both says to use them only if you are "not likely to
lose access to your private EdDSA key". Verification this strict means a lost key
costs updates outright. That is what the two unticked custody boxes above are
about, and they remain unticked: enabling these keys does not settle custody, it
raises the cost of not settling it. Recovery is possible — releases are also
Apple Developer ID signed, so a rebuilt key can be pushed — but it is a manual
recovery, not a non-event.

## Freshness of this pin

A pin nobody re-visits is a pin that rots: this ADR's premise is that Sparkle
releases carry security fixes, so the pin's safety argument has an expiry
date. The check is mechanised rather than remembered:
`data-sources.yml` runs `sparkle-pin-freshness` on a monthly schedule, reads
the pin from the project's `exactVersion` requirement in `project.pbxproj`
(what the app actually builds against), and
fails against the live latest release when they differ. A red run is the
trigger to re-read this ADR — not an automatic bump. Bumping remains the
release-contract decision this document describes.

The check reads `project.pbxproj` rather than `Package.resolved` because Xcode
deletes the lockfile: `-resolvePackageDependencies` resolves correctly and then
relocates it out of `project.xcworkspace/xcshareddata/swiftpm/` entirely, leaving
a tracked-file deletion in the working tree. Resolution is unaffected — resolving
with the lockfile absent still yields 2.9.6, because this requirement is what
governs it — but a check that reads a file the toolchain deletes would eventually
fail for a reason unrelated to Sparkle.

`Package.resolved` is therefore no longer the pin's source of truth, but it stays
tracked as a record of what a release was built against. **Expect it to show as
deleted after any local Xcode 27 build.** That is Xcode's behaviour, not a change
to the pin: restore it with `git checkout` and do not commit the deletion. If it
is ever genuinely stale, re-resolve and commit the result rather than deleting it
by hand, so the diff shows a version change instead of a removal.
