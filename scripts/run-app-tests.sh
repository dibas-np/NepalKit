#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Runs the app-layer test suite through the SwiftPM harness in scripts/apptests.
#
# Usage: scripts/run-app-tests.sh [extra swift test args]

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
harness="$repo_root/scripts/apptests"

# The harness must symlink the real app sources; copies drift silently.
for pair in "Sources/NepalKit:NepalKit" "Tests/NepalKitTests:NepalKitTests"; do
    link="${pair%%:*}"
    expected="${pair##*:}"
    path="$harness/$link"

    if [[ ! -L "$path" ]]; then
        echo "error: $path must be a symlink to ../../../$expected" >&2
        echo "       The harness compiles the real app sources; a copy drifts." >&2
        echo "       Fix: ln -sfn ../../../$expected $path" >&2
        exit 1
    fi

    if [[ ! -e "$path" ]]; then
        echo "error: $path is a dangling symlink (expected ../../../$expected)" >&2
        exit 1
    fi
done

# InfoPlistKeysTests check a built product. Use the newest NepalKit.app found,
# unless it is older than its sources, in which case those tests skip. The
# executable's mtime is used because Xcode does not always rewrite Info.plist.
if [[ -z "${NEPAKIT_BUILT_PLIST:-}" ]]; then
    # Inputs that affect the built Info.plist and bundled resources.
    newest_input="$(find "$repo_root/NepalKit" "$repo_root/NepalKit.xcodeproj/project.pbxproj" \
        "$repo_root/LICENSE" -type f -not -name .DS_Store -exec stat -f '%m %N' {} + | sort -rn)"
    newest_line="${newest_input%%$'\n'*}"
    newest_mtime="${newest_line%% *}"
    newest_path="${newest_line#* }"

    product=""
    product_mtime=0
    for candidate in "$repo_root"/DerivedData/Build/Products/Debug/NepalKit.app \
                     "$repo_root"/build/Products/Debug/NepalKit.app \
                     "$HOME"/Library/Developer/Xcode/DerivedData/NepalKit-*/Build/Products/Debug/NepalKit.app; do
        if [[ -f "$candidate/Contents/Info.plist" && -f "$candidate/Contents/MacOS/NepalKit" ]]; then
            candidate_mtime="$(stat -f %m "$candidate/Contents/MacOS/NepalKit")"
            if [[ "$candidate_mtime" -gt "$product_mtime" ]]; then
                product="$candidate"
                product_mtime="$candidate_mtime"
            fi
        fi
    done

    if [[ -z "$product" ]]; then
        echo "==> no built product found, so the seven plist tests will skip"
    elif [[ -n "$newest_mtime" ]] && [[ "$product_mtime" -lt "$newest_mtime" ]]; then
        echo "==> not using the built product at $product, because it is stale"
        echo "    product $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$product/Contents/MacOS/NepalKit")"
        echo "    source  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$newest_path")"
        echo "    rebuild, or point NEPAKIT_BUILT_PLIST at a current product; the seven plist tests skip"
    else
        NEPAKIT_BUILT_PLIST="$product/Contents/Info.plist"
        export NEPAKIT_BUILT_PLIST
        echo "==> checking the built product at $product"
        echo "    product $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$product/Contents/MacOS/NepalKit")"
        echo "    source  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$newest_path")"
    fi
fi

echo "==> app-layer tests (scripts/apptests)"
cd "$harness"
exec swift test "$@"
