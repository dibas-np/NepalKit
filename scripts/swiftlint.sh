#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(<"$repo_root/.swiftlint-version")"
expected_checksum="c3a1d77647ca18c1b7e9be7dbc6cd4490d26422f28814b76370244ff61970869"
expected_binary_checksum="52112ece2dfa99c2442a1367f9a365d43784714cf224c3675bf8bc2f18ebd7c8"

tool_dir="$repo_root/.build/tools/swiftlint/$version"
tool="$tool_dir/swiftlint"
if [[ ! -x "$tool" ]]; then
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "$temporary_dir"' EXIT
    archive="$temporary_dir/SwiftLintBinary.artifactbundle.zip"
    url="https://github.com/realm/SwiftLint/releases/download/$version/SwiftLintBinary.artifactbundle.zip"
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

# Trust the cached copy by its bytes, not by the version it reports.
actual_binary_checksum="$(shasum -a 256 "$tool" | cut -d ' ' -f 1)"
if [[ "$actual_binary_checksum" != "$expected_binary_checksum" ]]; then
    echo "$tool is not the pinned SwiftLint $version binary; delete it to download it again" >&2
    exit 1
fi

exec "$tool" "$@"
