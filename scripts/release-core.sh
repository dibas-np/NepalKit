#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Publishes NepalKitCore as a Swift package release (ADR-0018).
#
#   scripts/release-core.sh --dry-run 0.2.0   # every check and the signed tag, nothing pushed
#   scripts/release-core.sh 0.2.0             # the same, then publish
#
# SwiftPM resolves a package only from the root of a repository, so the package
# is published to a mirror, dibas-np/NepalKitCore. The mirror's main is
# `git subtree split --prefix=NepalKitCore` of this repository. The split is
# deterministic, so anyone can rerun it and compare commits, and each release
# only fast-forwards it.
#
# What a run does, in order:
#
#   1. Refuses a malformed version, a dirty tree, a HEAD that is not
#      origin/$CORE_RELEASE_BRANCH, a missing changelog entry, or a tag that
#      already exists on either side.
#   2. Splits the subtree into a private bare repository under $WORK and clones
#      it. The suites run in that clone, so what is tested is exactly what is
#      published, without the rest of this repository around it.
#   3. Runs the core suite on macOS, an iOS Simulator and a watchOS Simulator.
#   4. Signs v<version> on the split commit, inside the bare repository. The
#      tag never exists in this repository: a v* tag here is an app release,
#      and pushing one starts release-tag.yml.
#   5. Pushes the mirror's main (fast-forward only) and the tag, signs and
#      pushes core-v<version> on this repository's HEAD as the source marker,
#      and creates the GitHub release on the mirror from the changelog entry.
#
# Simulator destinations can be overridden for a machine with other runtimes
# installed: CORE_IOS_DESTINATION, CORE_WATCHOS_DESTINATION.
set -euo pipefail

ROOT="${0:A:h:h}"
PREFIX=NepalKitCore
MIRROR_REPO="${CORE_MIRROR_REPO:-dibas-np/NepalKitCore}"
MIRROR_URL="https://github.com/$MIRROR_REPO.git"
BRANCH="${CORE_RELEASE_BRANCH:-develop}"
IOS_DESTINATION="${CORE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
WATCHOS_DESTINATION="${CORE_WATCHOS_DESTINATION:-platform=watchOS Simulator,name=Apple Watch SE 3 (44mm),OS=26.0}"

DRY_RUN=0
if [[ "${1:-}" == --dry-run ]]; then
    DRY_RUN=1
    shift
fi
if (( $# != 1 )); then
    print -u2 "usage: scripts/release-core.sh [--dry-run] <major.minor.patch>"
    exit 64
fi
VERSION="$1"
TAG="v$VERSION"
SOURCE_TAG="core-v$VERSION"

fail() {
    print -u2 "release-core: $1"
    exit 1
}

# A dirty or unpushed tree is fatal for a real release, because the published
# commits must be ones the monorepo already shows. A dry run only reports it, so
# the script can be exercised before its own commit is pushed.
fail_unless_dry_run() {
    if (( DRY_RUN )); then
        print -u2 "release-core: warning (dry run): $1"
    else
        fail "$1"
    fi
}

step() {
    print "\n==> $1"
}

[[ "$VERSION" =~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] \
    || fail "'$VERSION' is not a major.minor.patch version"

cd "$ROOT"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/NepalKitCore-release.XXXXXXXX")"
cleanup() {
    rm -rf "$WORK"
    return 0
}
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

step "Preconditions for NepalKitCore $VERSION"

[[ -z "$(git status --porcelain)" ]] || fail_unless_dry_run "the working tree has uncommitted changes"

git fetch --quiet origin "$BRANCH"
HEAD_SHA="$(git rev-parse HEAD)"
[[ "$HEAD_SHA" == "$(git rev-parse "origin/$BRANCH")" ]] \
    || fail_unless_dry_run "HEAD is not origin/$BRANCH; push it, or check out the commit being released"

# The section from "## <version> — " up to the next "## " heading, which becomes
# the GitHub release notes. An entry is required: the changelog is the only
# place a consumer reads what a 0.x minor release broke. Read from HEAD, which is
# what gets published, not from the working tree.
NOTES="$WORK/notes.md"
git show "HEAD:$PREFIX/CHANGELOG.md" > "$WORK/CHANGELOG.md" 2>/dev/null \
    || fail "HEAD has no $PREFIX/CHANGELOG.md"
awk -v heading="## $VERSION — " '
    index($0, heading) == 1 { found = 1; next }
    found && /^## / { exit }
    found { print }
' "$WORK/CHANGELOG.md" > "$NOTES"
[[ -n "$(tr -d '[:space:]' < "$NOTES")" ]] || fail "$PREFIX/CHANGELOG.md has no '## $VERSION — <date>' entry"

gh repo view "$MIRROR_REPO" --json name > /dev/null 2>&1 \
    || fail "$MIRROR_REPO does not exist or gh cannot reach it"
[[ -z "$(git tag --list "$SOURCE_TAG")" ]] || fail "$SOURCE_TAG already exists in this repository"
[[ -z "$(git ls-remote --tags origin "refs/tags/$SOURCE_TAG")" ]] || fail "$SOURCE_TAG already exists on origin"
[[ -z "$(git ls-remote --tags "$MIRROR_URL" "refs/tags/$TAG")" ]] || fail "$TAG already exists on $MIRROR_REPO"

SIGNING_KEY="$(git config user.signingkey)" || fail "no user.signingkey; release tags are signed"
SIGNING_FORMAT="$(git config gpg.format || print openpgp)"
ALLOWED_SIGNERS="$(git config gpg.ssh.allowedSignersFile || true)"

step "Splitting $PREFIX/"

SPLIT_SHA="$(git subtree split --quiet --prefix="$PREFIX" HEAD)"
print "split: $SPLIT_SHA (source $HEAD_SHA)"

MIRROR="$WORK/mirror.git"
# --initial-branch, so the clone below checks out main rather than an unborn
# default branch.
git init --quiet --bare --initial-branch=main "$MIRROR"
git push --quiet "$MIRROR" "${SPLIT_SHA}:refs/heads/main"
git -C "$MIRROR" cat-file -e "main:Package.swift" 2>/dev/null || fail "the split has no Package.swift at its root"

if [[ -n "$(git ls-remote --heads "$MIRROR_URL" main)" ]]; then
    git -C "$MIRROR" fetch --quiet "$MIRROR_URL" "main:refs/remotes/mirror/main"
    git -C "$MIRROR" merge-base --is-ancestor mirror/main main \
        || fail "$MIRROR_REPO's main is not an ancestor of the split; the mirror was changed outside this script"
fi

CHECKOUT="$WORK/checkout"
git clone --quiet "$MIRROR" "$CHECKOUT"

step "Core suite on macOS"
(cd "$CHECKOUT" && swift test --quiet)

# The summary line is required as well as the exit status, so a destination
# that builds but runs no tests cannot pass as a tested platform.
run=0
for destination in "$IOS_DESTINATION" "$WATCHOS_DESTINATION"; do
    step "Core suite on $destination"
    log="$WORK/xcodebuild-$(( ++run )).log"
    (cd "$CHECKOUT" && xcodebuild test -scheme NepalKitCore \
        -destination "$destination" -derivedDataPath "$WORK/DerivedData") > "$log" 2>&1 \
        || { tail -40 "$log" >&2; fail "the core suite failed on $destination"; }
    grep -E "Test run with [1-9][0-9]* tests" "$log" || fail "no tests ran on $destination"
done

step "Signing $TAG on the split"

git -C "$MIRROR" -c gpg.format="$SIGNING_FORMAT" -c user.signingkey="$SIGNING_KEY" \
    tag -s "$TAG" -m "NepalKitCore $VERSION" main
if [[ -n "$ALLOWED_SIGNERS" ]]; then
    git -C "$MIRROR" -c gpg.format="$SIGNING_FORMAT" -c gpg.ssh.allowedSignersFile="$ALLOWED_SIGNERS" \
        tag -v "$TAG"
fi

if (( DRY_RUN )); then
    print "\nDry run: every check passed and $TAG is signed. Nothing was pushed."
    print "A real run would publish $SPLIT_SHA to $MIRROR_REPO as $TAG, and tag $HEAD_SHA as $SOURCE_TAG."
    exit 0
fi

step "Publishing"

# set -e stops the run at the first refusal, and each line printed below says
# what has already gone out, so a partial publish is never silent.
git -C "$MIRROR" push --quiet "$MIRROR_URL" main "refs/tags/$TAG"
print "pushed $MIRROR_REPO main and $TAG"

git tag -s "$SOURCE_TAG" -m "NepalKitCore $VERSION, published to $MIRROR_REPO as $TAG ($SPLIT_SHA)" "$HEAD_SHA"
git push --quiet origin "refs/tags/$SOURCE_TAG"
print "pushed $SOURCE_TAG on origin"

gh release create "$TAG" --repo "$MIRROR_REPO" --verify-tag \
    --title "NepalKitCore $VERSION" --notes-file "$NOTES"

print "\nNepalKitCore $VERSION is published: https://github.com/$MIRROR_REPO/releases/tag/$TAG"
