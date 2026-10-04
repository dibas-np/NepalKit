# Verifying a NepalKit release

How to check, before you install it, that a NepalKit you downloaded is the one
the project published — and that it came from the person who publishes it.

You can skip all of this. macOS already does it: a notarized, stapled build that
has been signed by a Developer ID certificate passes Gatekeeper on first launch
without a prompt. This document exists for the cases where you **want** to check
rather than trust the check having happened, and for the Homebrew path, where
there is no signature check at all.

## What you are verifying, and against what

Two separate questions, and they have different answers:

1. **Is this archive intact and authentic?** → Apple's code signature and
   notarization ticket.
2. **Did the right person publish it?** → the signing identity and team, and the
   Ed25519 signature on the update feed.

### The expected values

| What | Expected value |
| --- | --- |
| Signing identity | `Developer ID Application: Dibas Sigdel (CA89X9954L)` |
| Team ID | `CA89X9954L` |
| Gatekeeper verdict | `accepted` / `source=Notarized Developer ID` |
| Update feed | `https://dibas-np.github.io/NepalKit/appcast.xml` |
| Feed signature algorithm | Ed25519, against `SUPublicEDKey` in the installed app's `Info.plist` |
| Release channel | <https://github.com/dibas-np/NepalKit/releases> |
| Homebrew cask | `dibas-np/tap/nepalkit` |

The signing identity and team are **not secret** — they are printed on every
signed build and are recorded in
[`docs/watch/readiness-evidence.md`](watch/readiness-evidence.md). An attacker who
controls your download can also print whatever they like here; that is why
question 2 is answered by Apple's infrastructure and not by this file. See
"Where the trust actually comes from" below.

## Verifying a downloaded DMG

On a Mac, with the DMG in `~/Downloads`. None of these steps installs anything.

### 1. Check what you actually have

```sh
ls -l ~/Downloads/NepalKit-*.dmg
shasum -a 256 ~/Downloads/NepalKit-*.dmg
```

If you installed with Homebrew, compare that digest against the one recorded in
the cask — Homebrew verifies it for you, and this is how you see what it
verified:

```sh
brew cat --cask dibas-np/tap/nepalkit | grep -A2 sha256
```

### 2. Check the signature and who signed it

```sh
codesign -dv --verbose=4 ~/Downloads/NepalKit-*.dmg 2>&1 | head -20
```

Expect `Developer ID Application: Dibas Sigdel (CA89X9954L)` and
`Authority=Developer ID Application`. **A different team here is a failure, not
a warning** — stop and read [SECURITY.md](../SECURITY.md).

### 3. Check the notarization ticket, offline

```sh
xcrun stapler validate ~/Downloads/NepalKit-*.dmg
```

This must succeed with the machine offline. A ticket that validates only with a
network connection means the stapling did not happen, and you should not install
the build.

### 4. Check Gatekeeper's own verdict

```sh
# Mount without installing.
hdiutil attach ~/Downloads/NepalKit-*.dmg -nobrowse -readonly
spctl -a -t execute -vvv /Volumes/NepalKit/NepalKit.app
hdiutil detach /Volumes/NepalKit
```

Expect `accepted` and `source=Notarized Developer ID`. The literal words
**Notarized** are the difference between a good and a bad answer: a build signed
but not notarized reports `source=Developer ID Application` or
`Unnotarized Developer ID`, and Gatekeeper will refuse it on another user's Mac
even though it opens on yours.

The volume name is `NepalKit` for every release; if `hdiutil attach` mounts it
somewhere else, use the path it prints.

### 5. Check the inner app, not just the image

A DMG carries no code signature of its own by design, which is why steps 2 and 4
both resolve to the `.app` inside it. This step is what `scripts/update-cask.sh`
automates before it records a digest:

```sh
codesign --verify --deep --strict --verbose=2 /Volumes/NepalKit/NepalKit.app
codesign -dv --verbose=4 /Volumes/NepalKit/NepalKit.app 2>&1 | grep -E 'TeamIdentifier|flags'
```

`flags` must include `runtime` — the hardened runtime. `package-release.sh` fails
the release if it is missing, because without it the hardened-runtime guarantees
the notarization rests on do not apply.

## Verifying the update feed

If you are already running NepalKit, the app verifies the feed and the archive
for you and refuses both when a signature is missing. To check the feed
independently:

```sh
curl -sS https://dibas-np.github.io/NepalKit/appcast.xml | head -40
```

You are looking for an `edSignature` element on the `<channel>` or on each
`<item>`. **`SUPublicEDKey` on its own is not enough**: it means the app is *able*
to verify a signature, not that it insists on one. An app that only verifies
downloads trusts whatever the feed names — so a tampered feed could point an
installation at a different archive. NepalKit refuses an unsigned feed, which is
what the 1.4.1 release added.

The public key is inside the installed app, not in this repository:

```sh
defaults read /Applications/NepalKit.app/Contents/Info SUPublicEDKey
```

## What this repository automates

Every check above also runs mechanically, so you do not have to:

| Check | Where | When |
| --- | --- | --- |
| Codesign identity, hardened runtime, notarization, stapling | `scripts/package-release.sh` | Every release build |
| DMG layout, window geometry, icon placement | `scripts/package-release.sh`, ADR-0013 | Every release build |
| Appcast structure, enclosure lengths, and the EdDSA signature over the real bytes | `scripts/verify-appcast.py`, run by `pages.yml` | Every change to `appcast.xml`, and on demand |
| Downloaded `.app` identity, version, and `sha256` for the cask | `scripts/update-cask.sh` | Every `v*` tag |
| Deployment floor agreement across project, script, and built product | `scripts/verify-deployment-floor.py` | Every pull request |
| Gatekeeper on a machine that has never trusted the developer | [`docs/release-evidence/fresh-mac-install-procedure.md`](release-evidence/fresh-mac-install-procedure.md) | Before publication |

The last one is the only check that cannot be done from a machine that already
has the signing certificate installed, which is exactly why it exists.

## Where the trust actually comes from

Honesty about this, because a verification document that implies it is the
trust anchor is worse than none.

**This file is not a trust anchor.** It is in the same repository as the pipeline
that produces the releases, so anyone who can rewrite `main` can rewrite this
page. The same is true of the Team ID, which is printed on every signed build.
Verifying a digest against a value from the same place you downloaded the file
proves only that the file matches itself.

What actually carries the trust:

- **Apple's notarization service.** A stapled ticket is a record, signed by
  Apple, that *this exact hash* of *this exact code* was submitted to and
  accepted by Apple's notary. An attacker who rewrites this repository does not
  have an Apple Developer account with notarization capability. The ticket is
  checked against Apple's infrastructure on a machine you trust — which is why it
  validates offline.
- **The Homebrew cask**, in a separate repository, whose digest is reviewed
  independently of this one and is the only check the `brew` path performs. That
  is why `update-cask.sh` refuses to compute a digest over bytes that have not
  already passed every other check.
- **The Ed25519 key**, whose private half is in one machine's keychain and is
  not in GitHub, in CI, or in this repository. See
  [secrets-policy.md](secrets-policy.md).

If you want independence from this repository entirely, the check to make is
step 3 and step 4 above — Apple's verdict — plus, if you are technical enough to
want it, Apple's
[notarization transparency log](https://developer.apple.com/news/?id=notary-log),
which is a public append-only record independent of both Apple and this project.

## If a check fails

Stop. Do not install it, and do not work around the warning — a Gatekeeper
warning that a workaround dismisses is the failure this document exists to catch.

Report it privately through [SECURITY.md](../SECURITY.md). Include which step
failed, its output, and the `shasum -a 256` digest from step 1. Do not open a
public issue for it.
