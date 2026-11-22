#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Builds the app and runs every local check. The build runs first because the
# app-layer suite reads the built Info.plist.
#
# Not run here: scripts/verify-data-sources.py (needs network) and the
# release-time scripts.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

total=16
ran=0
summary=""
current=""

report() {
    local status=$?
    printf '\n==> summary\n'
    if [[ -n "$summary" ]]; then
        printf '%s' "$summary"
    fi
    if [[ "$status" -ne 0 ]]; then
        printf '  FAIL  %s\n' "$current"
        printf '\n==> FAILED at: %s\n' "$current"
    else
        printf '\n==> all %d gates passed\n' "$total"
    fi
}
trap report EXIT

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

derived="$repo_root/DerivedData"
gate "app and Xcode test targets build" bash -c '
    set -euo pipefail
    xcodebuild -project "$1/NepalKit.xcodeproj" -scheme NepalKit \
        -configuration Debug -derivedDataPath "$2" \
        -destination "platform=macOS,arch=$(uname -m)" CODE_SIGNING_ALLOWED=NO build-for-testing
    plist="$2/Build/Products/Debug/NepalKit.app/Contents/Info.plist"
    if [[ ! -f "$plist" ]]; then
        echo "the build reported success but produced no Info.plist at $plist" >&2
        exit 1
    fi
' _ "$repo_root" "$derived"
NEPAKIT_BUILT_PLIST="$derived/Build/Products/Debug/NepalKit.app/Contents/Info.plist"
export NEPAKIT_BUILT_PLIST

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
# Registers and unregisters throwaway bundles in this session's LaunchServices
# database, so it needs a logged-in macOS session and does not run in CI.
gate "LaunchServices unregistration suite" python3 "$repo_root/scripts/test_unregister_launchservices.py"
gate "appcast verification suite" python3 "$repo_root/scripts/test_verify_appcast.py"
gate "release product verifier suite" python3 "$repo_root/scripts/test_verify_release_product.py"
gate "coverage parser suite" python3 "$repo_root/scripts/test_measure_coverage.py"
gate "coverage floor" python3 "$repo_root/scripts/measure-coverage.py"
gate "deployment floor consistency" bash -c '
    set -euo pipefail
    python3 "$1/scripts/test_verify_deployment_floor.py"
    python3 "$1/scripts/verify-deployment-floor.py"
' _ "$repo_root"
gate "package release script suite" python3 "$repo_root/scripts/test_release_core.py"
gate "Watch support tests (NepalKitWatchSupport)" bash -c 'cd "$1" && swift test' _ "$repo_root/NepalKitWatchSupport"
# Needs this exact simulator; xcodebuild lists the available ones if it is missing.
gate "Watch suite (watchOS Simulator)" xcodebuild test \
    -project "$repo_root/NepalKit.xcodeproj" \
    -scheme "NepalKitWatch Watch App" \
    -configuration Debug \
    -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=27.0' \
    CODE_SIGNING_ALLOWED=NO
