#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Unregister bundles from LaunchServices, and prove they are gone.
#
# Every app bundle a build or packaging run creates registers itself with
# LaunchServices, keyed by its path. Those registrations outlive the bundle:
# `lsregister -u` on a path that no longer exists fails with -10814 and leaves
# the entry in place, so a pipeline that builds under fresh mktemp paths and
# then deletes them seeds a permanent entry per run. The dev machine carried
# 90+ stale registrations for one bundle id before this was handled, which
# made bundle-id resolution ambiguous for system services - including the App
# Shortcuts registration path.
#
# So this must run BEFORE the temp directory is removed, which is why the
# packaging script calls it from its cleanup trap rather than after it.
#
# The -u call is not trusted to have worked: it is re-checked with a database
# dump, and a bundle that is still registered makes this exit non-zero. The
# dump is a few seconds, once, at the end of a release.
#
# Usage: scripts/unregister-launchservices.sh <bundle> [bundle...]
#
# Always succeeds for a path that was never registered (nothing to prove), and
# fails for a path that was registered and could not be removed - or one that
# was already deleted, which is the ordering mistake this exists to catch.

set -euo pipefail

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if [ ! -x "$LSREGISTER" ]; then
    echo "error: $LSREGISTER is missing; nothing can be unregistered" >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "usage: $(basename "$0") <bundle> [bundle...]" >&2
    exit 2
fi

# A bundle's own registration is recorded under its path and under paths
# nested inside it (Sparkle's Updater.app lives in Contents/Frameworks), so a
# surviving match anywhere beneath the bundle counts.
registered_paths_under() {
    local dump
    dump=$("$LSREGISTER" -dump) || {
        echo "error: could not inspect the LaunchServices database" >&2
        return 1
    }
    printf '%s\n' "$dump" | NK_LS_BUNDLE_PATH="$1" awk '
        BEGIN { bundle = ENVIRON["NK_LS_BUNDLE_PATH"] }
        /^[[:space:]]*path:[[:space:]]/ {
            sub(/^[[:space:]]*path:[[:space:]]+/, "")
            sub(/ \(0x[0-9a-fA-F]+\)$/, "")
            if ($0 == bundle || index($0, bundle "/") == 1) print
        }
    '
}

declare -a still_registered=()
declare -a gone_before_we_ran=()

for bundle in "$@"; do
    if [ ! -e "$bundle" ]; then
        # The exact failure this script is placed to prevent: the caller
        # cleaned up first. Recorded rather than silently skipped, because
        # nothing downstream can detect it.
        gone_before_we_ran+=("$bundle")
        echo "error: $bundle is already gone; a deleted bundle cannot be unregistered" >&2
        continue
    fi

    # `|| true`: lsregister exits non-zero for paths it cannot scan, and one
    # uncooperative path must not stop the others from being cleaned up. The
    # re-check below is what decides whether the work actually landed.
    "$LSREGISTER" -u "$bundle" >/dev/null 2>&1 || true

    # The dump records the *resolved* path, so a bundle under a symlinked
    # temporary directory (`/var` -> `/private/var` on macOS) is registered
    # under a string the caller never passed. Checking only what was given
    # would read as "nothing left" while the stale entry sits there — the
    # verification passing is the whole point of this script, so it has to
    # query the path the database actually holds.
    resolved=$(cd "$bundle" 2>/dev/null && pwd -P) || resolved="$bundle"
    if ! remaining=$(registered_paths_under "$resolved"); then
        still_registered+=("$bundle")
        echo "error: could not verify unregistration of $bundle" >&2
        continue
    fi
    if [ -n "$remaining" ]; then
        still_registered+=("$bundle")
        echo "error: still registered after unregistering:" >&2
        echo "$remaining" | sed 's/^/  /' >&2
    else
        echo "unregistered: $bundle"
    fi
done

status=0
if [ "${#gone_before_we_ran[@]}" -gt 0 ]; then
    status=1
fi
if [ "${#still_registered[@]}" -gt 0 ]; then
    status=1
fi
exit "$status"
