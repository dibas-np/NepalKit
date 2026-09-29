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
if [ -z "${NEPAKIT_BUILT_PLIST:-}" ]; then
    for candidate in "$repo_root"/build/Products/Debug/NepalKit.app \
                     "$HOME"/Library/Developer/Xcode/DerivedData/NepalKit-*/Build/Products/Debug/NepalKit.app; do
        if [ -f "$candidate/Contents/Info.plist" ]; then
            NEPAKIT_BUILT_PLIST="$candidate/Contents/Info.plist"
            export NEPAKIT_BUILT_PLIST
            echo "==> checking the built product at $candidate"
            break
        fi
    done
fi

echo "==> app-layer tests (scripts/apptests)"
cd "$harness"
exec swift test "$@"
