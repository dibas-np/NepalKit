# Verifying a NepalKit release

How to check, before you install it, that a NepalKit you downloaded is the one
the project published — and that it came from the person who publishes it.

You can skip all of this. macOS already does it: a notarized, stapled build that
has been signed by a Developer ID certificate passes Gatekeeper on first launch
without a prompt. This document exists for the cases where you **want** to check
rather than trust the check having happened.

## What you are verifying, and against what

Two separate questions, and they have different answers:

1. **Is this archive intact and authentic?** → Apple's code signature and
   notarization ticket.
2. **Did the right person publish it?** → the signing identity and team, and the
   Ed25519 signature on the update feed.

### The expected values

| What | Expected value |
| --- | --- |
| Signing identity | `Developer ID Application: Finnove Technologies (CA89X9954L)` |
| Team ID | `CA89X9954L` |
| Gatekeeper verdict | `accepted` / `source=Notarized Developer ID` |
| Update feed | `https://dibas-np.github.io/NepalKit/appcast.xml` |
| Feed signature algorithm | Ed25519, against `SUPublicEDKey` in the installed app's `Info.plist` |
| Release channel | <https://github.com/dibas-np/NepalKit/releases> |
| Homebrew cask | `dibas-np/tap/nepalkit` |

The signing identity and team are **not secret** — they are printed on every
signed build. An attacker who
controls your download can also print whatever they like here; that is why
question 2 is answered by Apple's infrastructure and not by this file. See
"Where the trust actually comes from" below.

## Verifying a downloaded DMG

On a Mac, with the DMG in `~/Downloads`. None of these steps installs anything.

### 1. Check what you actually have

```sh
ls -l ~/Downloads/NepalKit.dmg
shasum -a 256 ~/Downloads/NepalKit.dmg
```

If you installed with Homebrew, compare that digest against the one recorded in
the cask — Homebrew verifies it for you, and this is how you see what it
verified:

```sh
brew cat --cask dibas-np/tap/nepalkit | grep -A2 sha256
```

### 2. Check the tag signature

A release carries two signatures. The **tag** says who cut the release; the
**archive** says what is inside it. Checking only the second tells you the bytes
are intact, not who published them.

Tags are signed with an SSH key, so Git needs to be told which key to trust
before `git tag -v` can verify one. Take the key from GitHub's record of the
account's signing keys, keeping only the one whose fingerprint matches the one
printed here, so the two sources have to agree and a mismatch stops the check:

```sh
expected='SHA256:HS2j4+5KUI65IlJo6M6Lr5DOlVufdBzIHGWp0JY7Jik'
rm -f nepalkit-signing.pub
curl -s https://api.github.com/users/dibas-np/ssh_signing_keys \
  | python3 -c 'import json, sys; [print(k["key"]) for k in json.load(sys.stdin)]' \
  | while read -r key; do
      printf '%s\n' "$key" > candidate.pub
      [ "$(ssh-keygen -lf candidate.pub | awk '{print $2}')" = "$expected" ] && mv candidate.pub nepalkit-signing.pub
    done
rm -f candidate.pub
test -s nepalkit-signing.pub || echo "FAIL: no GitHub signing key has fingerprint $expected"
printf 'dibas-np@github.com namespaces="git" %s\n' "$(cat nepalkit-signing.pub)" > nepalkit-allowed-signers

git fetch --tags
git -c gpg.ssh.allowedSignersFile=nepalkit-allowed-signers tag -v v<version>
```

From `v1.6.1` on, expect `Good "git" signature for dibas-np@github.com with
ED25519 key SHA256:HS2j4+5KUI65IlJo6M6Lr5DOlVufdBzIHGWp0JY7Jik` - the same key
the commits are signed with. A different fingerprint at either step is a
failure. `git tag -v` is the only check here that verifies a signature.

The eight earlier release tags (`1.0`, `1.1`, `1.2`, `v1.3.0` to `v1.6.0`) are
lightweight, so `git tag -v` reports that they are not tag objects; for those
releases, rely on the archive and code signatures in the steps below. To see
whether a tag is annotated at all:

```sh
git cat-file -t v<version>     # tag    -> annotated (may or may not be signed)
                               # commit -> lightweight, carries no signature
```

### 3. Mount it, then check the archive signature

**A `.dmg` carries no code signature of its own, by design.** `codesign` on the
image reports nothing useful, and `spctl` on the image always says "no usable
signature" — which is why step 5 below assesses the `.app` inside. So the
identity check runs against the app, not the disk image:

```sh
hdiutil attach ~/Downloads/NepalKit.dmg -nobrowse -readonly
codesign --verify --deep --strict --verbose=2 /Volumes/NepalKit/NepalKit.app
codesign -dv --verbose=4 /Volumes/NepalKit/NepalKit.app 2>&1 | grep -E 'TeamIdentifier|Authority|flags'
```

`codesign --verify` must report the app valid on disk: the signature verifies,
so the app is unmodified.

Expect `TeamIdentifier=CA89X9954L`; that is the value to match. The Authority
line names the organisation that holds the team: 1.6.0 prints
`Authority=Developer ID Application: Finnove Technologies (CA89X9954L)`. **A different team here is a failure, not a
warning** — stop and read [SECURITY.md](../SECURITY.md).

`flags` must include `runtime` — the hardened runtime. `package-release.sh` fails
the release if it is missing, because without it the hardened-runtime guarantees
the notarization rests on do not apply.

The volume name is `NepalKit` for every release; if `hdiutil attach` mounts it
somewhere else, use the path it prints. Leave it mounted for step 5.

### 4. Check the notarization ticket, offline

```sh
xcrun stapler validate ~/Downloads/NepalKit.dmg
```

This must succeed with the machine offline. A ticket that validates only with a
network connection means the stapling did not happen, and you should not install
the build.

### 5. Check Gatekeeper's own verdict

```sh
# Still mounted from step 3. Assess without installing.
spctl -a -t execute -vvv /Volumes/NepalKit/NepalKit.app
hdiutil detach /Volumes/NepalKit
```

Expect `accepted` and `source=Notarized Developer ID`. The literal words
**Notarized** are the difference between a good and a bad answer: a build signed
but not notarized reports `source=Developer ID Application` or
`Unnotarized Developer ID`, and Gatekeeper will refuse it on another user's Mac
even though it opens on yours.

## Verifying the update feed

If you are already running NepalKit, the app verifies the feed and the archive
for you and refuses both when a signature is missing. To check the feed
independently, run the verifier from a clone of this repository. It checks the
feed's signature, then fetches each enclosure and checks its Ed25519 signature
against the committed public key:

```sh
python3 scripts/verify-appcast.py appcast.xml --info-plist NepalKit/Info.plist
```

That is the same check CI runs on every change to the feed
(`.github/workflows/pages.yml`) and the same one the release machine runs
before publishing.

**`SUPublicEDKey` on its own is not enough**: it means the app is *able*
to verify a signature, not that it insists on one. An app that only verifies
downloads trusts whatever the feed names — so a tampered feed could point an
installation at a different archive. NepalKit refuses an unsigned feed, which is
what the 1.4.1 release added.

The public key is `SUPublicEDKey` in `NepalKit/Info.plist`; compare it with the
installed app's copy:

```sh
defaults read /Applications/NepalKit.app/Contents/Info SUPublicEDKey
```

## Verifying a NepalKitCore release

<https://github.com/dibas-np/NepalKitCore> mirrors `NepalKitCore/`. Each `v<version>`
there has a `core-v<version>` here on the source commit. Check that both are
signed with the key from step 2, and that the mirror's commit is the split of
this repository. Build `nepalkit-allowed-signers` as in step 2, then, with full
clones (`git subtree split` cannot work from `--depth`):

```sh
git clone https://github.com/dibas-np/NepalKitCore.git
git -C NepalKitCore -c gpg.ssh.allowedSignersFile="$PWD/nepalkit-allowed-signers" tag -v v<version>
mirrored="$(git -C NepalKitCore rev-parse 'v<version>^{commit}')"

git clone https://github.com/dibas-np/NepalKit.git
git -C NepalKit -c gpg.ssh.allowedSignersFile="$PWD/nepalkit-allowed-signers" tag -v core-v<version>
test "$(git -C NepalKit subtree split --quiet --prefix=NepalKitCore core-v<version>)" = "$mirrored" \
  && echo "mirror matches" || echo "FAIL: the mirror is not the split of core-v<version>"
```

Expect a `Good "git" signature` for both tags, then `mirror matches`. The
mirror's commits are unsigned (the split rewrites them); the signed tag covers
the tree.

## Where the trust actually comes from

**This file is not a trust anchor.** It lives in the same repository as the
release pipeline, so anyone who can rewrite `main` can rewrite this page.

What actually carries the trust:

- **Apple's notarization service.** A stapled ticket is a record, signed by
  Apple, that *this exact hash* of *this exact code* was submitted to and
  accepted by Apple's notary. An attacker who rewrites this repository does not
  have an Apple Developer account with notarization capability. The ticket is
  checked against Apple's infrastructure on a machine you trust — which is why it
  validates offline.
- **The Ed25519 key**, whose private half is in one machine's keychain and is
  not in GitHub, in CI, or in this repository.

If you want independence from this repository entirely, the check to make is
steps 4 and 5 above — Apple's verdict.

## If a check fails

Stop. Do not install it, and do not work around the warning — a Gatekeeper
warning that a workaround dismisses is the failure this document exists to catch.

Report it privately through [SECURITY.md](../SECURITY.md). Include which step
failed, its output, and the `shasum -a 256` digest from step 1. Do not open a
public issue for it.
