#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Runs the complete app-layer test suite.
#
# `xcodebuild test` builds NepalKit clean but the test runner hangs before
# connecting in this environment, so the app-layer suite runs through a
# SwiftPM harness instead. See docs/adr/0005-app-layer-test-execution.md.
#
# Usage: scripts/run-app-tests.sh [extra swift test args]

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
harness="$repo_root/scripts/apptests"

# The harness must reference the real app sources by symlink. It used to hold
# copies, which drifted silently: the copies predated the menu-bar midnight
# timer and the hardened converter clamping, so "24 tests passing" was reported
# against code the app no longer contained. Fail loudly if that regresses.
for pair in "Sources/NepalKit:NepalKit" "Tests/NepalKitTests:NepalKitTests"; do
    link="${pair%%:*}"
    expected="${pair##*:}"
    path="$harness/$link"

    if [ ! -L "$path" ]; then
        echo "error: $path must be a symlink to ../../../$expected" >&2
        echo "       The harness compiles the real app sources; a copy drifts." >&2
        echo "       Fix: ln -sfn ../../../$expected $path" >&2
        exit 1
    fi

    if [ ! -e "$path" ]; then
        echo "error: $path is a dangling symlink (expected ../../../$expected)" >&2
        exit 1
    fi
done

# `InfoPlistKeysTests` checks the *built* product rather than the project,
# because a key the build discards cannot be caught by reading the project.
# The harness has no app bundle of its own, so it is pointed at one here.
#
# Nothing set this before, which meant those five tests were skipped in every
# run and still counted as passing - the Sparkle public key, LSUIElement and
# the installer-launcher key were unguarded in practice. A build is discovered
# if one exists and is never built here: this script's reason to exist is that
# it needs no Xcode, and the gate stays honest by skipping with a stated
# reason when there is genuinely nothing to check.
#
# "A build exists" turned out not to be enough. The glob below matches every
# `NepalKit-*` DerivedData directory on the machine - a stale branch, a renamed
# project, a second checkout - and the first match won, in glob order, which is
# alphabetical and reflects how Xcode hashed the directory, not which build is
# current. A product from last week could therefore be read as authoritative
# and the suite would report five release-critical keys verified against a
# build this source does not produce. Same failure class as the symlink drift
# recorded above, one level up: the count looks right and the thing it counted
# is wrong.
#
# So the newest product wins, and a product older than the source that builds it
# is not used at all - the five tests skip with their own stated reason rather
# than pass against a stale bundle. The comparison is printed either way, so a
# reader can see it instead of inferring it.
#
# Skipping rather than failing, deliberately. Failing here would break the plain
# `./scripts/run-app-tests.sh` that README and CONTRIBUTING tell every
# contributor to run, on a machine with no build at all - a state that is
# normal, not a mistake. What is preserved is the contract the header above
# states: a test that cannot check something must not report that it did.
# Exiting non-zero is the stricter reading of the same requirement and is
# defensible, but it is a change of policy for a documented command rather than
# a fix to a wrong one, so it is not made here.
if [ -z "${NEPAKIT_BUILT_PLIST:-}" ]; then
    # Everything whose mtime decides whether this product is current: the app
    # target's sources and the plist, entitlements and assets it embeds; the
    # build settings that decide which INFOPLIST_KEY_* survive; and LICENSE,
    # which a resource phase copies into the bundle and one of the five tests
    # asserts on. The core package is deliberately not in this set - it does not
    # feed the plist or the resources, so its mtime would skip checks that are
    # still perfectly meaningful.
    #
    # `stat -f %m` is BSD form and this is a macOS-only repository. No
    # `find -printf`: that is GNU and does not exist here.
    newest_input="$(find "$repo_root/NepalKit" "$repo_root/NepalKit.xcodeproj/project.pbxproj" \
        "$repo_root/LICENSE" -type f -exec stat -f '%m %N' {} + | sort -rn)"
    newest_line="${newest_input%%$'\n'*}"
    newest_mtime="${newest_line%% *}"
    newest_path="${newest_line#* }"

    # The newest product, not the first one the glob yields. Kept
    # `build/Products/Debug/…` even though current Xcode puts SYMROOT in
    # DerivedData and the path is dead on this machine: it costs one failed
    # test, and it is the shape a checkout with its own SYMROOT would use.
    product=""
    product_mtime=0
    for candidate in "$repo_root"/build/Products/Debug/NepalKit.app \
                     "$HOME"/Library/Developer/Xcode/DerivedData/NepalKit-*/Build/Products/Debug/NepalKit.app; do
        if [ -f "$candidate/Contents/Info.plist" ]; then
            candidate_mtime="$(stat -f %m "$candidate/Contents/Info.plist")"
            if [ "$candidate_mtime" -gt "$product_mtime" ]; then
                product="$candidate"
                product_mtime="$candidate_mtime"
            fi
        fi
    done

    if [ -z "$product" ]; then
        # Said out loud. Previously the absence of a product was indistinguishable
        # from the five tests having run.
        echo "==> no built product found, so the five plist tests will skip"
    elif [ -n "$newest_mtime" ] && [ "$product_mtime" -lt "$newest_mtime" ]; then
        echo "==> not using the built product at $product, because it is stale"
        echo "    product $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$product/Contents/Info.plist")"
        echo "    source  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$newest_path")"
        echo "    rebuild, or point NEPAKIT_BUILT_PLIST at a current product; the five plist tests skip"
    else
        NEPAKIT_BUILT_PLIST="$product/Contents/Info.plist"
        export NEPAKIT_BUILT_PLIST
        echo "==> checking the built product at $product"
        echo "    product $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$product/Contents/Info.plist")"
        echo "    source  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$newest_path")"
    fi
fi

echo "==> app-layer tests (scripts/apptests)"
cd "$harness"
exec swift test "$@"
