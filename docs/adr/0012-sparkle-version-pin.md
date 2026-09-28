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
