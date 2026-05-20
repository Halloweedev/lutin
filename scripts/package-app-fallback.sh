#!/usr/bin/env bash
# DOCUMENTED FALLBACK — only run if lutin itself is broken and a release is
# urgent. Uses plain hdiutil instead of going through the renderer.
# Produces a minimal, unsigned DMG containing the .app bundle.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$REPO_ROOT/Apps/LutinApp/build/Lutin.app}"
OUT="${2:-$REPO_ROOT/release/Lutin-fallback.dmg}"

mkdir -p "$(dirname "$OUT")"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
hdiutil create -volname Lutin -srcfolder "$STAGE" -fs HFS+ \
    -format UDZO -ov "$OUT"
rm -rf "$STAGE"
echo "Wrote $OUT (fallback path; unsigned)"
