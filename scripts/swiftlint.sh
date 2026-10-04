#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(<"$repo_root/.swiftlint-version")"
expected_checksum="c3a1d77647ca18c1b7e9be7dbc6cd4490d26422f28814b76370244ff61970869"

if command -v swiftlint >/dev/null 2>&1 && [[ "$(swiftlint version)" = "$version" ]]; then
    exec swiftlint "$@"
fi

tool_dir="$repo_root/.build/tools/swiftlint/$version"
tool="$tool_dir/swiftlint"
if [[ ! -x "$tool" ]]; then
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "$temporary_dir"' EXIT
    archive="$temporary_dir/SwiftLintBinary.artifactbundle.zip"
    url="https://github.com/realm/SwiftLint/releases/download/$version/SwiftLintBinary.artifactbundle.zip"
    # `--proto '=https'` is load-bearing next to `--location`, not decoration:
    # -L follows a redirect to whatever scheme the response names, including
    # plain http, and a downgrade would move this download out of TLS. The
    # checksum below would still have something to compare against, so a
    # downgraded fetch that happens to match would be indistinguishable from a
    # good one. Refuse the downgrade instead of trusting the host not to ask.
    curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error "$url" --output "$archive"
    actual_checksum="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
        echo "SwiftLint $version archive checksum did not match" >&2
        exit 1
    fi
    unzip -q "$archive" -d "$temporary_dir"
    bundled_tool="$temporary_dir/SwiftLintBinary.artifactbundle/macos/swiftlint"
    if [[ ! -f "$bundled_tool" ]]; then
        echo "SwiftLint $version archive did not contain its macOS executable" >&2
        exit 1
    fi
    mkdir -p "$tool_dir"
    install -m 755 "$bundled_tool" "$tool"
fi

actual_version="$("$tool" version)"
if [[ "$actual_version" != "$version" ]]; then
    echo "Expected SwiftLint $version, found $actual_version" >&2
    exit 1
fi

exec "$tool" "$@"
