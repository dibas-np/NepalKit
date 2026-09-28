# Sparkle 2.9.6, pinned clear of CVE-2026-47122

**Part of ticket 07. The pinned version is a release-contract item: it is what
ships, and it is what the security position rests on.**

NepalKit uses Sparkle for in-application updates. The version is pinned
deliberately rather than tracked, because Sparkle's own releases have repeatedly
carried security fixes and "whatever is newest at integration time" is not a
position anyone can defend later.

**Chosen: Sparkle 2.9.6** (released 17 August 2026), the current release.

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
- `SUFeedURL` is still absent, deliberately, until a feed is published.

Both of the first two were verified to fail when injected, with messages that
name the consequence rather than the assertion.
