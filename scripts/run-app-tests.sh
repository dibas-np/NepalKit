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

echo "==> app-layer tests (scripts/apptests)"
cd "$harness"
exec swift test "$@"
