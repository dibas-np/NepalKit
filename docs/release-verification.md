# How to verify a NepalKit download

Use these steps to confirm that a NepalKit you downloaded is the build the
project published. Gatekeeper already runs Apple's checks when you first open
the app, so you need this guide only to check by hand.

The expected values on this page live in the same repository as the release
scripts, so anyone who can change the repository can change them too. Apple's
notarization and Gatekeeper checks do not depend on this page.

## Check the DMG

These steps assume the DMG is at `~/Downloads/NepalKit.dmg`. None of them
installs anything.

### 1. Record the checksum

```sh
shasum -a 256 ~/Downloads/NepalKit.dmg
```

The Homebrew cask records the digest of the current release's DMG. Compare
yours with it:

```sh
brew cat --cask dibas-np/tap/nepalkit | grep -A2 sha256
```

### 2. Check the app's code signature

`codesign` reports the DMG itself as not signed, so check the app inside it:

```sh
hdiutil attach ~/Downloads/NepalKit.dmg -nobrowse -readonly
codesign --verify --deep --strict --verbose=2 /Volumes/NepalKit/NepalKit.app
codesign -dv --verbose=4 /Volumes/NepalKit/NepalKit.app 2>&1 | grep -E 'TeamIdentifier|Authority|flags'
```

`codesign --verify` must end with `valid on disk` and `satisfies its Designated
Requirement`. The second `codesign` command must print these lines:

- `Authority=Developer ID Application: Finnove Technologies (CA89X9954L)`
- `TeamIdentifier=CA89X9954L`
- a `CodeDirectory` line with `flags=0x10000(runtime)`, the hardened runtime
  that notarization requires

A different team is a failure. If `hdiutil attach` mounts the volume somewhere
other than `/Volumes/NepalKit`, use the path it prints. Leave the volume
mounted for step 4.

### 3. Check the notarization ticket

```sh
xcrun stapler validate ~/Downloads/NepalKit.dmg
```

Expect `The validate action worked!`. The command needs a network connection,
because it downloads the ticket from Apple.

### 4. Check Gatekeeper's verdict

```sh
spctl -a -t execute -vvv /Volumes/NepalKit/NepalKit.app
diskutil eject /Volumes/NepalKit
```

Expect these three lines:

```text
/Volumes/NepalKit/NepalKit.app: accepted
source=Notarized Developer ID
origin=Developer ID Application: Finnove Technologies (CA89X9954L)
```

Any other `source` is a failure.

## Check the release tag

The tag records who published the release. The maintainer signs tags with an
SSH key, so first build an allowed-signers file for `git tag -v`. The script below takes
the key from GitHub's list of the account's signing keys and keeps it only if
its fingerprint matches the one on this page:

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
```

In the same directory, clone the repository and verify the tag. Replace
`<version>` with the release version, such as `1.7.0`:

```sh
git clone https://github.com/dibas-np/NepalKit.git
git -C NepalKit -c gpg.ssh.allowedSignersFile="$PWD/nepalkit-allowed-signers" tag -v v<version>
```

Expect `Good "git" signature for dibas-np@github.com with ED25519 key
SHA256:HS2j4+5KUI65IlJo6M6Lr5DOlVufdBzIHGWp0JY7Jik`. A different fingerprint is
a failure.

Tags before `v1.6.1` (`1.0`, `1.1`, `1.2`, and `v1.3.0` to `v1.6.0`) are not
signed. For those, `git tag -v` reports `cannot verify a non-tag object of type
commit`, and the DMG checks are the only checks.

## Check the update feed

The installed app checks the feed's signature and each update's signature
itself, and refuses an update when either is missing. To check the feed
yourself, run the verifier from the clone, in the same directory as before:

```sh
curl -fsSL -o feed.xml https://dibas-np.github.io/NepalKit/appcast.xml
python3 NepalKit/scripts/verify-appcast.py feed.xml --info-plist NepalKit/NepalKit/Info.plist
```

The script checks the feed's signature, downloads each update archive the feed
lists, and checks each archive's Ed25519 signature against `SUPublicEDKey` in
`NepalKit/Info.plist`. Expect the last line to be `Appcast is sound.`

Then confirm that the installed app has the same public key as the repository.
These two commands must print the same value:

```sh
plutil -extract SUPublicEDKey raw NepalKit/NepalKit/Info.plist
defaults read /Applications/NepalKit.app/Contents/Info SUPublicEDKey
```

## Check a NepalKitCore release

<https://github.com/dibas-np/NepalKitCore> mirrors `NepalKitCore/`. Each
`v<version>` tag there has a matching `core-v<version>` tag in this repository,
on the source commit. Check that both tags are signed with the same key as the
release tag, and that the mirror's commit is the split of this repository.
Replace `<version>` with the package version, such as `0.1.0`.

Run these commands in the same directory as the release-tag check. It holds
`nepalkit-allowed-signers` and the full `NepalKit` clone. `git subtree split`
fails in a clone made with `--depth`.

```sh
git clone https://github.com/dibas-np/NepalKitCore.git
git -C NepalKitCore -c gpg.ssh.allowedSignersFile="$PWD/nepalkit-allowed-signers" tag -v v<version>
mirrored="$(git -C NepalKitCore rev-parse 'v<version>^{commit}')"

git -C NepalKit -c gpg.ssh.allowedSignersFile="$PWD/nepalkit-allowed-signers" tag -v core-v<version>
test "$(git -C NepalKit subtree split --quiet --prefix=NepalKitCore core-v<version>)" = "$mirrored" \
  && echo "mirror matches" || echo "FAIL: the mirror is not the split of core-v<version>"
```

Expect a `Good "git" signature` line for each tag, then `mirror matches`. The
mirror's commits are not signed, because the split rewrites them. The signed
tag covers the tree.

## Report a failed check

If any check fails, do not install the app and do not bypass the Gatekeeper
warning. Report the failure privately as [SECURITY.md](../SECURITY.md)
describes, not in a public issue. Include the step that failed, its output, and
the `shasum -a 256` digest from step 1.
