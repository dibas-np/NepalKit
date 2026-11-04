#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Publishes NepalKitCore as a Swift package release (ADR-0018).
#
#   scripts/release-core.sh --dry-run 0.2.0   # every check and both signed tags, nothing pushed
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
#      origin/$CORE_RELEASE_BRANCH, a missing changelog entry, signing that
#      cannot be verified, or a release tag that already names another commit.
#      A remote that cannot be asked is a failure, never "no such tag".
#   2. Splits the subtree into a private bare repository under $WORK and clones
#      it. The suites run in that clone, so what is tested is exactly what is
#      published, without the rest of this repository around it.
#   3. Runs the core suite on macOS, an iOS Simulator and a watchOS Simulator.
#   4. Signs v<version> on the split and core-v<version> on HEAD, each in a
#      private repository, and requires a good signature from the key named in
#      docs/release-verification.md on both. Neither tag exists in this
#      repository before it is published: a v* tag here is an app release, and
#      pushing one starts release-tag.yml.
#   5. Pushes the mirror's main and its tag in one atomic push, then the source
#      tag, then creates the GitHub release from the changelog entry.
#
# Nothing is pushed until both tags are signed and verified. A run that stops
# partway through step 5 can be rerun with the same version: a step whose
# result is already published at the commit this run would publish is skipped.
#
# Overrides, for another machine and for scripts/test_release_core.py:
# CORE_RELEASE_BRANCH, CORE_MIRROR_REPO, CORE_MIRROR_URL, CORE_IOS_DESTINATION,
# CORE_WATCHOS_DESTINATION and CORE_SIGNING_FINGERPRINT.
set -euo pipefail

ROOT="${0:A:h:h}"
PREFIX=NepalKitCore
MIRROR_REPO="${CORE_MIRROR_REPO:-dibas-np/NepalKitCore}"
MIRROR_URL="${CORE_MIRROR_URL:-https://github.com/$MIRROR_REPO.git}"
BRANCH="${CORE_RELEASE_BRANCH:-develop}"
# The simulator runtimes installed on the release machine. The iOS suite runs
# on iOS 27 because no iOS 26 runtime is installed there; the manifest's iOS 26
# floor is compiled against, not run (ADR-0018).
IOS_DESTINATION="${CORE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
WATCHOS_DESTINATION="${CORE_WATCHOS_DESTINATION:-platform=watchOS Simulator,name=Apple Watch SE 3 (44mm),OS=26.0}"
# The key docs/release-verification.md tells consumers to expect. A tag that
# verifies against any other key is refused before anything is pushed.
EXPECTED_FINGERPRINT="${CORE_SIGNING_FINGERPRINT:-SHA256:HS2j4+5KUI65IlJo6M6Lr5DOlVufdBzIHGWp0JY7Jik}"

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

# The commit a ref names on a remote, peeled through an annotated tag, or
# nothing when the remote has no such ref. A remote that cannot be asked fails
# the run: read as "no such ref", an unreachable mirror would skip the very
# checks that guard it. Call as `x="$(remote_commit …)" || exit 1`.
remote_commit() {
    local url="$1" ref="$2" out="" peeled=""
    local -i code=0
    out="$(git ls-remote --exit-code "$url" "$ref" "$ref^{}")" || code=$?
    case $code in
        0) ;;
        2) return 0 ;;
        *) fail "cannot read $ref from $url (git ls-remote exited $code)" ;;
    esac
    peeled="$(print -r -- "$out" | awk -v ref="$ref^{}" '$2 == ref { print $1 }')"
    if [[ -n "$peeled" ]]; then
        print -r -- "$peeled"
    else
        print -r -- "${out%%[[:space:]]*}"
    fi
}

# Whether the mirror already has a GitHub release for $TAG. Only a 404 means
# no; any other answer stops the run rather than guessing.
release_exists() {
    local out=""
    if out="$(gh api "repos/$MIRROR_REPO/releases/tags/$TAG" --jq .tag_name 2>&1)"; then
        return 0
    elif [[ "$out" == *"HTTP 404"* ]]; then
        return 1
    fi
    fail "cannot ask GitHub whether $MIRROR_REPO has a $TAG release: $out"
}

# Every user.* and gpg.* value this repository sees, wherever it is set, copied
# into a private repository so it signs exactly as this one does. A repo-local
# gpg.ssh.program, or an identity set only here, would otherwise be lost.
inherit_signing_config() {
    local repo="$1" key="" value=""
    { git config --get-regexp '^(user|gpg)\.' || true; } | while read -r key value; do
        git -C "$repo" config "$key" "$value"
    done
}

# Signs $tag on $target inside $repo, then requires a good signature from the
# expected key. Printing the verification line puts it in the release log.
sign_and_verify() {
    local repo="$1" tag="$2" target="$3" message="$4" report=""
    git -C "$repo" tag -s "$tag" -m "$message" "$target"
    report="$(git -C "$repo" tag -v "$tag" 2>&1)" || fail "$tag does not verify: $report"
    [[ "$report" == *"Good \"git\" signature"*"$EXPECTED_FINGERPRINT"* ]] \
        || fail "$tag is not signed by $EXPECTED_FINGERPRINT: $report"
    print -r -- "$report" | grep '^Good'
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

# Release tags are SSH-signed, and `tag -v` needs an allowed-signers file to
# check one. A machine that cannot verify a tag cannot release: a signature
# nobody checked before publishing is not one consumers should rely on.
[[ "$(git config gpg.format || true)" == ssh ]] \
    || fail "gpg.format is not ssh; release tags are SSH-signed (docs/release-verification.md)"
git config user.signingkey > /dev/null || fail "no user.signingkey; release tags are signed"
git config gpg.ssh.allowedSignersFile > /dev/null \
    || fail "no gpg.ssh.allowedSignersFile, so the tags could not be verified before they are pushed"

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

step "Splitting $PREFIX/"

SPLIT_SHA="$(git subtree split --quiet --prefix="$PREFIX" HEAD)"
print "split: $SPLIT_SHA (source $HEAD_SHA)"

MIRROR="$WORK/mirror.git"
# --initial-branch, so the clone below checks out main rather than an unborn
# default branch.
git init --quiet --bare --initial-branch=main "$MIRROR"
git push --quiet "$MIRROR" "${SPLIT_SHA}:refs/heads/main"
git -C "$MIRROR" cat-file -e "main:Package.swift" 2>/dev/null || fail "the split has no Package.swift at its root"

# What is already published, read once. Each publish step below is either still
# to do, or already done at exactly the commit this run would publish; anything
# else is refused, because a published release does not move.
MIRROR_MAIN="$(remote_commit "$MIRROR_URL" refs/heads/main)" || exit 1
MIRROR_TAGGED="$(remote_commit "$MIRROR_URL" "refs/tags/$TAG")" || exit 1
SOURCE_TAGGED="$(remote_commit origin "refs/tags/$SOURCE_TAG")" || exit 1
LOCAL_SOURCE="$(git rev-parse --quiet --verify "refs/tags/$SOURCE_TAG^{commit}" || true)"

[[ -z "$MIRROR_TAGGED" || "$MIRROR_TAGGED" == "$SPLIT_SHA" ]] \
    || fail "$TAG on $MIRROR_REPO is $MIRROR_TAGGED, not this split ($SPLIT_SHA)"
[[ -z "$SOURCE_TAGGED" || "$SOURCE_TAGGED" == "$HEAD_SHA" ]] \
    || fail "$SOURCE_TAG on origin is $SOURCE_TAGGED, not HEAD ($HEAD_SHA)"
[[ -z "$LOCAL_SOURCE" || "$LOCAL_SOURCE" == "$HEAD_SHA" ]] \
    || fail "$SOURCE_TAG already exists in this repository, at $LOCAL_SOURCE"

if [[ -n "$MIRROR_MAIN" ]]; then
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

step "Signing $TAG on the split and $SOURCE_TAG on HEAD"

if [[ -z "$MIRROR_TAGGED" ]]; then
    inherit_signing_config "$MIRROR"
    sign_and_verify "$MIRROR" "$TAG" main "NepalKitCore $VERSION"
else
    print "$TAG is already on $MIRROR_REPO at the split; it is not signed again"
fi

# The source tag is made in a second private repository that borrows this one's
# objects, so it never exists here until origin has it.
SOURCE="$WORK/source.git"
if [[ -z "$SOURCE_TAGGED" ]]; then
    git init --quiet --bare "$SOURCE"
    print -r -- "$(git rev-parse --path-format=absolute --git-common-dir)/objects" \
        > "$SOURCE/objects/info/alternates"
    inherit_signing_config "$SOURCE"
    sign_and_verify "$SOURCE" "$SOURCE_TAG" "$HEAD_SHA" \
        "NepalKitCore $VERSION, published to $MIRROR_REPO as $TAG ($SPLIT_SHA)"
else
    print "$SOURCE_TAG is already on origin at HEAD; it is not signed again"
fi

if (( DRY_RUN )); then
    print "\nDry run: every check passed, and every tag still to publish is signed. Nothing was pushed."
    print "A real run would publish $SPLIT_SHA to $MIRROR_REPO as $TAG, and tag $HEAD_SHA as $SOURCE_TAG."
    exit 0
fi

step "Publishing"

if [[ -z "$MIRROR_TAGGED" ]]; then
    # Atomic, so the mirror never has a main without its tag, or a tag the
    # branch has not reached.
    git -C "$MIRROR" push --quiet --atomic "$MIRROR_URL" main "refs/tags/$TAG"
    print "pushed $MIRROR_REPO main and $TAG"
fi

if [[ -z "$SOURCE_TAGGED" ]]; then
    git -C "$SOURCE" push --quiet "$(git remote get-url --push origin)" "refs/tags/$SOURCE_TAG"
    print "pushed $SOURCE_TAG on origin"
fi
git fetch --quiet origin "refs/tags/${SOURCE_TAG}:refs/tags/${SOURCE_TAG}"

if release_exists; then
    print "the $TAG release already exists on $MIRROR_REPO"
else
    gh release create "$TAG" --repo "$MIRROR_REPO" --verify-tag \
        --title "NepalKitCore $VERSION" --notes-file "$NOTES"
fi

print "\nNepalKitCore $VERSION is published: https://github.com/$MIRROR_REPO/releases/tag/$TAG"
