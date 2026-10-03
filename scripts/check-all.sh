#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Runs every automated gate a contributor can run locally. See
# docs/adr/0005-app-layer-test-execution.md for why the app-layer suite goes
# through the SwiftPM harness rather than `xcodebuild test`.
#
# The build runs FIRST, which breaks the fastest-fails-first order the rest of
# this script follows, and the exception is load-bearing. scripts/apptests
# excludes NepalKitApp.swift and SparkleUpdateService.swift - correctly, since a
# library target cannot own @main and the harness links only NepalKitCore - and
# run-app-tests.sh discovers a built product rather than making one. So without a
# build ahead of it, InfoPlistKeysTests has nothing to read and skips, and a
# skipped test still reports as passing. Five gates that guard the release keys
# would be dark on every run that had not just built.
#
# That exclusion is also how SWIFT_VERSION = 6.0 shipped a file the app target
# could not compile: every gate here passed, for twenty-two plans, because the
# only file that broke lives in the one file none of them builds. The first gate
# is the one that would have caught it.
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
# It compiles the app and Xcode test bundle, including their actor-isolation
# settings and hosted linkage, which the SwiftPM harness cannot check.
# macos26-floor.yml builds the app in CI on every push to main and every pull request; this is the local
# half of that, so a contributor finds a broken app target here rather than in a
# pull-request log.
#
# Both are run by CI (`data-sources.yml`, `pages.yml`) on every change that
# touches them; this command is the local half, not a replacement.
#
# Usage: scripts/check-all.sh

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

total=10
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

# First, and out of order on purpose - see the header. `build-for-testing`
# compiles and links both targets without launching the hosted test runner:
# ADR-0005 records the runner hang that originally required the SwiftPM harness.
# Signing is off so a local run needs no credentials. The product is exported
# so the plist tests below read the built
# Info.plist rather than skipping.
derived="$repo_root/DerivedData"
gate "app and Xcode test targets build" bash -c '
    set -euo pipefail
    xcodebuild -project "$1/NepalKit.xcodeproj" -scheme NepalKit \
        -configuration Debug -derivedDataPath "$2" \
        -destination "platform=macOS,arch=$(uname -m)" CODE_SIGNING_ALLOWED=NO build-for-testing
    plist="$2/Build/Products/Debug/NepalKit.app/Contents/Info.plist"
    if [ ! -f "$plist" ]; then
        echo "the build reported success but produced no Info.plist at $plist" >&2
        exit 1
    fi
    echo "NEPAKIT_BUILT_PLIST=$plist"
' _ "$repo_root" "$derived"
# The gate above ran in a subshell, so its export did not reach this one.
if [ -f "$derived/Build/Products/Debug/NepalKit.app/Contents/Info.plist" ]; then
    NEPAKIT_BUILT_PLIST="$derived/Build/Products/Debug/NepalKit.app/Contents/Info.plist"
    export NEPAKIT_BUILT_PLIST
fi

gate "SwiftLint" bash -c '
    set -euo pipefail
    python3 "$1/scripts/test_swiftlint.py"
    "$1/scripts/swiftlint.sh" lint --strict
' _ "$repo_root"
gate "core tests (NepalKitCore)" bash -c 'cd "$1" && swift test' _ "$repo_root/NepalKitCore"
gate "app-layer tests (scripts/apptests)" "$repo_root/scripts/run-app-tests.sh"
gate "dataset parser suite" python3 "$repo_root/scripts/test_dataset_parsers.py"
gate "cask updater suite" python3 "$repo_root/scripts/test_update_cask.py"
gate "changelog suite" python3 "$repo_root/scripts/test_update_changelog.py"
# Runs before the appcast suite only because it is the one gate that touches
# the machine rather than the repository: it registers and unregisters real
# throwaway bundles in this session's LaunchServices database.
gate "LaunchServices unregistration suite" python3 "$repo_root/scripts/test_unregister_launchservices.py"
gate "appcast verification suite" python3 "$repo_root/scripts/test_verify_appcast.py"
# After the build gate, so the built product exists and the check can compare
# the floor the app actually shipped against the ones only declared. This is
# the gate that would have caught the 26.0/26.6 drift before a user did:
# every other gate here agreed, because they all trusted a declared number
# rather than comparing the sources to each other.
gate "deployment floor consistency" python3 "$repo_root/scripts/verify-deployment-floor.py"
