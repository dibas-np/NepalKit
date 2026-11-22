#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Unregister app bundles from LaunchServices and check they are gone.
#
# Run this before deleting a bundle: `lsregister -u` on a path that no longer
# exists fails and leaves a stale registration behind. Exits non-zero if a
# bundle is already deleted or is still registered afterwards.
#
# Usage: scripts/unregister-launchservices.sh <bundle> [bundle...]

set -euo pipefail

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if [[ ! -x "$LSREGISTER" ]]; then
    echo "error: $LSREGISTER is missing; nothing can be unregistered" >&2
    exit 1
fi

if [[ "$#" -eq 0 ]]; then
    echo "usage: $(basename "$0") <bundle> [bundle...]" >&2
    exit 2
fi

# Matches the bundle's path and anything nested in it (e.g. Sparkle's Updater.app).
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
    if [[ ! -e "$bundle" ]]; then
        gone_before_we_ran+=("$bundle")
        echo "error: $bundle is already gone; a deleted bundle cannot be unregistered" >&2
        continue
    fi

    # One failing path must not stop the others; the re-check below decides.
    "$LSREGISTER" -u "$bundle" >/dev/null 2>&1 || true

    # The database records the resolved path (/var -> /private/var).
    resolved=$(cd "$bundle" 2>/dev/null && pwd -P) || resolved="$bundle"
    if ! remaining=$(registered_paths_under "$resolved"); then
        still_registered+=("$bundle")
        echo "error: could not verify unregistration of $bundle" >&2
        continue
    fi
    if [[ -n "$remaining" ]]; then
        still_registered+=("$bundle")
        echo "error: still registered after unregistering:" >&2
        echo "$remaining" | sed 's/^/  /' >&2
    else
        echo "unregistered: $bundle"
    fi
done

status=0
if [[ "${#gone_before_we_ran[@]}" -gt 0 ]]; then
    status=1
fi
if [[ "${#still_registered[@]}" -gt 0 ]]; then
    status=1
fi
exit "$status"
