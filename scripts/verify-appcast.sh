#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Build the Sparkle appcast for a packaged release, then verify it.
#
# The appcast is generated into a staging directory, not into the repository.
# That is deliberate: `generate_appcast` builds enclosure URLs from a prefix and
# the archive filename, so the `1.0/` release-tag segment has to be supplied per
# version. Baking one into a committed file would silently rot at 1.0.1 - the
# feed would keep pointing at the 1.0 release and every future update 404. The
# feed is a per-release artifact, published alongside the release it describes.
#
# Usage: scripts/verify-appcast.sh <archives-dir> [download-url-prefix]
set -euo pipefail

ROOT="${0:A:h:h}"
ARCHIVES_DIR="${1:?usage: $0 <archives-dir> [download-url-prefix]}"
# Default assumes a GitHub release tag matching the marketing version. Override
# for any other layout, e.g. a flat asset path.
URL_PREFIX="${2:-}"

PY="${ROOT}/scripts/verify-appcast.py"
PLIST="${ROOT}/NepalKit/Info.plist"

if [[ ! -d "$ARCHIVES_DIR" ]]; then
    echo "no such archives directory: $ARCHIVES_DIR" >&2
    exit 1
fi

# Sparkle's tooling is not vendored, and its path contains a DerivedData hash
# that changes per machine. Search for it rather than hardcoding. SPARKLE_BIN
# overrides, which is what CI and a clean checkout use.
if [[ -n "${SPARKLE_BIN:-}" ]]; then
    GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"
else
    GENERATE_APPCAST=""
    for candidate in ${HOME}/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast(N); do
        GENERATE_APPCAST="$candidate"
    done
fi
if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
    echo "generate_appcast not found." >&2
    echo "Set SPARKLE_BIN to the Sparkle bin directory, e.g." >&2
    echo "  SPARKLE_BIN=\$(dirname \$(which generate_appcast)) scripts/verify-appcast.sh <dir>" >&2
    exit 1
fi
echo "using $GENERATE_APPCAST"

if [[ -z "$URL_PREFIX" ]]; then
    # Derive the newest archive's version and use it as the release tag.
    NEWEST=(${ARCHIVES_DIR}/*.zip(Nom[1]))
    [[ -e "$NEWEST" ]] || NEWEST=(${ARCHIVES_DIR}/*.dmg(Nom[1]))
    [[ -e "$NEWEST" ]] || { echo "no archives in $ARCHIVES_DIR" >&2; exit 1; }
    TAG="${NEWEST:t:r}"          # NepalKit-1.0.zip -> NepalKit-1.0
    TAG="${TAG#*-}"             # -> 1.0
    URL_PREFIX="https://github.com/dibas-np/NepalKit/releases/download/$TAG"
    echo "derived release tag '$TAG' from ${NEWEST:t}"
fi

echo "generating appcast in $ARCHIVES_DIR"
echo "release url prefix: $URL_PREFIX"

# `--download-url-prefix` replaces the prefix's last path component with the
# archive filename rather than appending to it, so a `1.0/` release-tag segment
# in the prefix is silently dropped: the generated url came out as
# `releases/download/NepalKit-1.0.zip`, which 404s. The url is therefore
# generated with a throwaway prefix and then corrected, rather than trusting a
# flag whose composition rule is not append.
#
# Rewriting the url afterwards is safe. The Ed25519 signature covers the
# enclosure *bytes*, not the url, so it is unaffected - and the verifier below
# proves that rather than assuming it. Re-running generate_appcast over an
# edited appcast would restore the bad url, so this runs exactly once.
# Signing happens here, from the keychain, where a human can approve the prompt.
"$GENERATE_APPCAST" \
    --download-url-prefix "https://nepalkit.invalid/placeholder" \
    --link "https://github.com/dibas-np/NepalKit" \
    "$ARCHIVES_DIR"

APPCAST="$ARCHIVES_DIR/appcast.xml"
[[ -f "$APPCAST" ]] || { echo "generate_appcast did not write an appcast" >&2; exit 1; }

# Repoint each enclosure at prefix + filename-as-uploaded. Done as a targeted
# text substitution rather than by reserialising the XML tree, so every other
# byte of the file - including the signature Sparkle just wrote - is untouched.
python3 - "$APPCAST" "$URL_PREFIX" <<'PYEOF'
import re
import sys
from pathlib import Path

appcast, prefix = Path(sys.argv[1]), sys.argv[2].rstrip("/")
raw = appcast.read_text(encoding="utf-8")

def repoint(match: "re.Match[str]") -> str:
    name = match.group(2).rsplit("/", 1)[-1]
    return f"{match.group(1)}{prefix}/{name}{match.group(3)}"

patched, count = re.subn(
    r'(<enclosure\b[^>]*\burl=")([^"]*)(")',
    repoint,
    raw,
)
if count == 0:
    print("  WARNING: no <enclosure> url found; the feed advertises nothing")
for match in re.finditer(r'<enclosure\b[^>]*\burl="([^"]*)"', patched):
    print(f"  url -> {match.group(1)}")
appcast.write_text(patched, encoding="utf-8")
PYEOF

# Embed the release notes. generate_appcast never writes descriptions, so
# without this step every release would depend on remembering a hand edit
# after generation — the same class of exactly-once edit as the url repoint
# above. Notes live in scripts/release-notes/<version>.html as HTML fragments,
# which Sparkle's alert renders, and are matched to items by
# sparkle:shortVersionString. An item whose version has no notes file fails
# the release: an unnoted update alert is the drift this step exists to
# prevent. Re-running over an already-described item is a no-op.
python3 - "$APPCAST" "${0:A:h}/release-notes" <<'PYEOF'
import re
import sys
from pathlib import Path

appcast, notes_dir = Path(sys.argv[1]), Path(sys.argv[2])
raw = appcast.read_text(encoding="utf-8")

def describe(match: "re.Match[str]") -> str:
    block = match.group(0)
    if "<description" in block:
        return block
    version = re.search(r"<sparkle:shortVersionString>([^<]+)</", block).group(1)
    notes = notes_dir / f"{version}.html"
    if not notes.exists():
        sys.exit(f"no release notes for version {version}: expected {notes}")
    body = notes.read_text(encoding="utf-8").strip()
    if "]]>" in body:
        sys.exit(f"{notes.name}: contains ]]>, which would terminate the CDATA "
                 f"block early and corrupt the feed")
    return re.sub(
        r"(\s*)<enclosure ",
        lambda m: f"\n            <description><![CDATA[\n{body}\n]]></description>\n            <enclosure ",
        block,
        count=1,
    )

described = re.sub(r"<item>.*?</item>", describe, raw, flags=re.S)
appcast.write_text(described, encoding="utf-8")
PYEOF

# Verify each enclosure locally. Uses only the committed public key, so this is
# safe to run anywhere - including CI, where the private key must never exist.
STATUS=0
for archive in ${ARCHIVES_DIR}/*.(zip|dmg)(N); do
    echo
    echo "verifying against $archive:t"
    python3 "$PY" "$APPCAST" --info-plist "$PLIST" --enclosure "$archive" || STATUS=1
done

exit $STATUS
