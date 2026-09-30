#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Runs every automated gate a contributor can run locally, in the order that
# fails fastest. See docs/adr/0005-app-layer-test-execution.md for why the
# app-layer suite goes through the SwiftPM harness rather than `xcodebuild test`.
#
# Why this exists: the repository had five suites and the contributor docs named
# two. `test_dataset_parsers.py` pins the month-length constants that a
# calendar-table edit has to hand-update, and nothing in the pull-request
# checklist said to run it, so a table change could reach review unchallenged.
# A gate nobody is told about is not a gate.
#
# What this does NOT run, so a green run is not mistaken for exhaustive:
#
#   - `scripts/verify-data-sources.py`, the provenance gate. It needs network
#     access and it is the first thing to reach for when the calendar table
#     changes; CONTRIBUTING.md's "The one thing that matters most" section
#     documents it separately, for that case.
#   - The other `scripts/verify-*` and `scripts/package-release.sh`, which are
#     release-time gates over packaged artifacts and a live feed.
#
# Both are run by CI (`data-sources.yml`, `pages.yml`) on every change that
# touches them; this command is the local half, not a replacement.
#
# Usage: scripts/check-all.sh

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

total=5
ran=0
summary=""
current=""

# Print the summary however the script leaves: a green run must be visibly a
# full run rather than an absence of output, and a red one must name the gate.
report() {
    local status=$?
    printf '\n==> summary\n'
    if [ -n "$summary" ]; then
        printf '%s' "$summary"
    fi
    if [ "$status" -ne 0 ]; then
        printf '  FAIL  %s\n' "$current"
        printf '\n==> FAILED at: %s\n' "$current"
    else
        printf '\n==> all %d gates passed\n' "$total"
    fi
}
trap report EXIT

# Announce the gate before running it, so a failure is identifiable from the
# output alone. The subshell keeps `cd` out of this script's own directory.
gate() {
    local name="$1"
    shift
    current="$name"
    ran=$((ran + 1))
    printf '\n==> [%d/%d] %s\n' "$ran" "$total" "$name"
    "$@"
    summary="$summary$(printf '  pass  %s' "$name")"$'\n'
    current=""
}

gate "core tests (NepalKitCore)" bash -c 'cd "$1" && swift test' _ "$repo_root/NepalKitCore"
gate "app-layer tests (scripts/apptests)" "$repo_root/scripts/run-app-tests.sh"
gate "dataset parser suite" python3 "$repo_root/scripts/test_dataset_parsers.py"
gate "changelog suite" python3 "$repo_root/scripts/test_update_changelog.py"
gate "appcast verification suite" python3 "$repo_root/scripts/test_verify_appcast.py"
