#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
#   scripts/release-core.sh --dry-run 0.2.0   # every check, nothing pushed
#   scripts/release-core.sh 0.2.0
#
# SwiftPM needs a package at a repository root, so releases go to the
# dibas-np/NepalKitCore mirror, whose main is `git subtree split
# --prefix=NepalKitCore` of this repository.
#
# Overrides: CORE_RELEASE_BRANCH, CORE_MIRROR_REPO, CORE_MIRROR_URL,
# CORE_IOS_DESTINATION, CORE_WATCHOS_DESTINATION, CORE_SIGNING_FINGERPRINT.
set -euo pipefail

ROOT="${0:A:h:h}"
PREFIX=NepalKitCore
MIRROR_REPO="${CORE_MIRROR_REPO:-dibas-np/NepalKitCore}"
MIRROR_URL="${CORE_MIRROR_URL:-https://github.com/$MIRROR_REPO.git}"
BRANCH="${CORE_RELEASE_BRANCH:-develop}"
IOS_DESTINATION="${CORE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
WATCHOS_DESTINATION="${CORE_WATCHOS_DESTINATION:-platform=watchOS Simulator,name=Apple Watch SE 3 (44mm),OS=26.0}"
EXPECTED_FINGERPRINT="${CORE_SIGNING_FINGERPRINT:-SHA256:HS2j4+5KUI65IlJo6M6Lr5DOlVufdBzIHGWp0JY7Jik}"
STAGING=refs/release-core

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

remote_ref() {
    local url="$1" ref="$2" out="" object="" peeled=""
    local -i code=0
    out="$(git ls-remote --exit-code "$url" "$ref" "$ref^{}")" || code=$?
    case $code in
        0) ;;
        2) return 0 ;;
        *) fail "cannot read $ref from $url (git ls-remote exited $code)" ;;
    esac
    object="$(print -r -- "$out" | awk -v ref="$ref" '$2 == ref { print $1 }')"
    peeled="$(print -r -- "$out" | awk -v ref="$ref^{}" '$2 == ref { print $1 }')"
    print -r -- "$object ${peeled:-$object}"
}

release_exists() {
    local out=""
    if out="$(gh api "repos/$MIRROR_REPO/releases/tags/$TAG" --jq .tag_name 2>&1)"; then
        return 0
    elif [[ "$out" == *"HTTP 404"* ]]; then
        return 1
    fi
    fail "cannot ask GitHub whether $MIRROR_REPO has a $TAG release: $out"
}

inherit_signing_config() {
    local repo="$1" key="" value=""
    { git config --get-regexp '^(user|gpg)\.' || true; } | while read -r key value; do
        case "$key" in
            user.signingkey|gpg.program|gpg.*.program|gpg.ssh.allowedsignersfile|gpg.ssh.revocationfile)
                if [[ "$value" != /* && "$value" != "~"* && "$value" != key::* && -e "$ROOT/$value" ]]; then
                    value="$ROOT/$value"
                fi
                ;;
        esac
        git -C "$repo" config "$key" "$value"
    done
}

verify_tag() {
    local ref="$1" name="$2" commit="$3" report="" good=""
    [[ "$(git cat-file -t "$ref")" == tag ]] || fail "$name is not an annotated tag, so it carries no signature"
    [[ "$(git cat-file tag "$ref" | awk '$1 == "tag" { print $2; exit }')" == "$name" ]] \
        || fail "the tag published as $name names itself something else"
    [[ "$(git rev-parse "$ref^{commit}")" == "$commit" ]] || fail "$name does not point at $commit"
    report="$(git verify-tag "$ref" 2>&1)" || fail "$name does not verify: $report"
    good="$(print -r -- "$report" | grep '^Good "git" signature for .* key ' || true)"
    [[ -n "$good" && "$good" != *$'\n'* && "${good##* key }" == "$EXPECTED_FINGERPRINT" ]] \
        || fail "$name is not signed by $EXPECTED_FINGERPRINT: $report"
    print -r -- "$name: $good"
}

[[ "$VERSION" =~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] \
    || fail "'$VERSION' is not a major.minor.patch version"

cd "$ROOT"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/NepalKitCore-release.XXXXXXXX")"
cleanup() {
    git for-each-ref --format='%(refname)' "$STAGING/" | while read -r ref; do
        git update-ref -d "$ref"
    done
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

[[ "$(git config gpg.format || true)" == ssh ]] \
    || fail "gpg.format is not ssh; release tags are SSH-signed (docs/release-verification.md)"
git config user.signingkey > /dev/null || fail "no user.signingkey; release tags are signed"
git config gpg.ssh.allowedSignersFile > /dev/null \
    || fail "no gpg.ssh.allowedSignersFile, so the tags could not be verified before they are pushed"

NOTES="$WORK/notes.md"
git show "HEAD:$PREFIX/CHANGELOG.md" > "$WORK/CHANGELOG.md" 2>/dev/null \
    || fail "HEAD has no $PREFIX/CHANGELOG.md"
awk -v heading="## $VERSION — " '
    index($0, heading) == 1 { found = 1; next }
    found && /^## / { exit }
    found { print }
' "$WORK/CHANGELOG.md" > "$NOTES"
[[ -n "$(tr -d '[:space:]' < "$NOTES")" ]] || fail "$PREFIX/CHANGELOG.md has no '## $VERSION — <date>' entry"
grep -qxE "## ${VERSION//./\\.} — [0-9]{4}-[0-9]{2}-[0-9]{2}" "$WORK/CHANGELOG.md" \
    || fail "$PREFIX/CHANGELOG.md's $VERSION heading has no YYYY-MM-DD release date"

gh repo view "$MIRROR_REPO" --json name > /dev/null 2>&1 \
    || fail "$MIRROR_REPO does not exist or gh cannot reach it"

step "Splitting $PREFIX/"

SPLIT_SHA="$(git subtree split --quiet --prefix="$PREFIX" HEAD)"
print "split: $SPLIT_SHA (source $HEAD_SHA)"
git cat-file -e "${SPLIT_SHA}:Package.swift" 2>/dev/null || fail "the split has no Package.swift at its root"

SPLIT_REPO="$WORK/split.git"
git init --quiet --bare --initial-branch=main "$SPLIT_REPO"
git push --quiet "$SPLIT_REPO" "${SPLIT_SHA}:refs/heads/main"

state="$(remote_ref "$MIRROR_URL" refs/heads/main)" || exit 1
read -r _ MIRROR_MAIN <<< "$state"
state="$(remote_ref "$MIRROR_URL" "refs/tags/$TAG")" || exit 1
read -r MIRROR_TAG_OBJECT MIRROR_TAGGED <<< "$state"
state="$(remote_ref origin "refs/tags/$SOURCE_TAG")" || exit 1
read -r SOURCE_TAG_OBJECT SOURCE_TAGGED <<< "$state"
LOCAL_SOURCE_OBJECT="$(git rev-parse --quiet --verify "refs/tags/$SOURCE_TAG" || true)"

[[ -z "$MIRROR_TAGGED" || "$MIRROR_TAGGED" == "$SPLIT_SHA" ]] \
    || fail "$TAG on $MIRROR_REPO is $MIRROR_TAGGED, not this split ($SPLIT_SHA)"
[[ -z "$SOURCE_TAGGED" || "$SOURCE_TAGGED" == "$HEAD_SHA" ]] \
    || fail "$SOURCE_TAG on origin is $SOURCE_TAGGED, not HEAD ($HEAD_SHA)"
[[ -z "$LOCAL_SOURCE_OBJECT" || "$LOCAL_SOURCE_OBJECT" == "$SOURCE_TAG_OBJECT" ]] \
    || fail "$SOURCE_TAG exists in this repository but is not the tag origin has; delete it (git tag -d $SOURCE_TAG) and rerun"

MAIN_NEEDS_PUSH=1
if [[ -n "$MIRROR_MAIN" ]]; then
    git fetch --quiet --no-tags "$MIRROR_URL" "+refs/heads/main:$STAGING/mirror-main"
    if git merge-base --is-ancestor "$SPLIT_SHA" "$STAGING/mirror-main"; then
        MAIN_NEEDS_PUSH=0
    elif ! git merge-base --is-ancestor "$STAGING/mirror-main" "$SPLIT_SHA"; then
        fail "$MIRROR_REPO's main has diverged from the split; the mirror was changed outside this script"
    fi
fi

step "Signing $TAG on the split and $SOURCE_TAG on HEAD"

if [[ -z "$MIRROR_TAG_OBJECT" ]]; then
    inherit_signing_config "$SPLIT_REPO"
    git -C "$SPLIT_REPO" tag -s "$TAG" -m "NepalKitCore $VERSION" main
    git fetch --quiet --no-tags "$SPLIT_REPO" "+refs/tags/${TAG}:$STAGING/$TAG"
else
    print "$TAG is already on $MIRROR_REPO; verifying it instead of signing a new one"
    git fetch --quiet --no-tags "$MIRROR_URL" "+refs/tags/${TAG}:$STAGING/$TAG"
fi
verify_tag "$STAGING/$TAG" "$TAG" "$SPLIT_SHA"

if [[ -z "$SOURCE_TAG_OBJECT" ]]; then
    SOURCE="$WORK/source.git"
    git init --quiet --bare "$SOURCE"
    print -r -- "$(git rev-parse --path-format=absolute --git-common-dir)/objects" \
        > "$SOURCE/objects/info/alternates"
    inherit_signing_config "$SOURCE"
    git -C "$SOURCE" tag -s "$SOURCE_TAG" \
        -m "NepalKitCore $VERSION, published to $MIRROR_REPO as $TAG ($SPLIT_SHA)" "$HEAD_SHA"
    git fetch --quiet --no-tags "$SOURCE" "+refs/tags/${SOURCE_TAG}:$STAGING/$SOURCE_TAG"
else
    print "$SOURCE_TAG is already on origin; verifying it instead of signing a new one"
    git fetch --quiet --no-tags origin "+refs/tags/${SOURCE_TAG}:$STAGING/$SOURCE_TAG"
fi
verify_tag "$STAGING/$SOURCE_TAG" "$SOURCE_TAG" "$HEAD_SHA"

CHECKOUT="$WORK/checkout"
git clone --quiet --no-tags "$SPLIT_REPO" "$CHECKOUT"

step "Core suite on macOS"
(cd "$CHECKOUT" && swift test --quiet)

run=0
for destination in "$IOS_DESTINATION" "$WATCHOS_DESTINATION"; do
    step "Core suite on $destination"
    log="$WORK/xcodebuild-$(( ++run )).log"
    (cd "$CHECKOUT" && xcodebuild test -scheme NepalKitCore \
        -destination "$destination" -derivedDataPath "$WORK/DerivedData") > "$log" 2>&1 \
        || { tail -40 "$log" >&2; fail "the core suite failed on $destination"; }
    grep -E "Test run with [1-9][0-9]* tests" "$log" || fail "no tests ran on $destination"
done

for platform in tvOS visionOS; do
    step "Core build for $platform"
    log="$WORK/xcodebuild-$(( ++run )).log"
    (cd "$CHECKOUT" && xcodebuild build -scheme NepalKitCore \
        -destination "generic/platform=$platform" -derivedDataPath "$WORK/DerivedData") > "$log" 2>&1 \
        || { tail -40 "$log" >&2; fail "the core did not build for $platform"; }
done

if (( DRY_RUN )); then
    print "\nDry run: every check passed, and both tags are verified. Nothing was pushed."
    print "A real run would publish $SPLIT_SHA to $MIRROR_REPO as $TAG, and tag $HEAD_SHA as $SOURCE_TAG."
    exit 0
fi

step "Publishing"

mirror_refs=()
(( MAIN_NEEDS_PUSH )) && mirror_refs+=("${SPLIT_SHA}:refs/heads/main")
[[ -n "$MIRROR_TAG_OBJECT" ]] || mirror_refs+=("$STAGING/${TAG}:refs/tags/${TAG}")
if (( ${#mirror_refs} )); then
    git push --quiet --atomic "$MIRROR_URL" "${mirror_refs[@]}"
    print "pushed to $MIRROR_REPO: ${mirror_refs[*]}"
fi

if [[ -z "$SOURCE_TAG_OBJECT" ]]; then
    git push --quiet origin "$STAGING/${SOURCE_TAG}:refs/tags/${SOURCE_TAG}"
    print "pushed $SOURCE_TAG to origin"
fi
[[ -n "$LOCAL_SOURCE_OBJECT" ]] \
    || git update-ref "refs/tags/$SOURCE_TAG" "$(git rev-parse "$STAGING/$SOURCE_TAG")"

if release_exists; then
    print "the $TAG release already exists on $MIRROR_REPO"
else
    gh release create "$TAG" --repo "$MIRROR_REPO" --verify-tag \
        --title "NepalKitCore $VERSION" --notes-file "$NOTES"
fi

print "\nNepalKitCore $VERSION is published: https://github.com/$MIRROR_REPO/releases/tag/$TAG"
