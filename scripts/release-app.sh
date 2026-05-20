#!/usr/bin/env bash
# Builds Lutin.app, assembles it into a .app via LutinAppPackager, then
# wraps it into a DMG using lutin itself (dogfood).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="${LUTIN_VERSION:-1.0.0}"
BUILD="${LUTIN_BUILD:-1}"

echo "→ swift build -c release"
swift build -c release --product lutin-app --product lutin --product lutin-app-packager

echo "→ Resolve resource bundle"
BIN="$REPO_ROOT/.build/release/lutin-app"
RES_DIR="$(find "$REPO_ROOT/.build/release" -maxdepth 1 -type d -name '*LutinUI*.bundle' -print -quit)"
if [[ -z "$RES_DIR" ]]; then
  echo "ERROR: could not locate the LutinUI resource bundle under .build/release" >&2
  echo "       (expected something like Lutin_LutinUI.bundle)" >&2
  exit 1
fi
echo "  bundle: $RES_DIR"

echo "→ Assemble Lutin.app"
OUT_DIR="$REPO_ROOT/Apps/LutinApp/build"
mkdir -p "$OUT_DIR"
"$REPO_ROOT/.build/release/lutin-app-packager" \
    "$BIN" "$RES_DIR" "$OUT_DIR" \
    --name=Lutin --bundle-id=com.lutin.app \
    --version="$VERSION" --build="$BUILD"

echo "→ Wrap with lutin (dogfood)"
cd "$REPO_ROOT/Apps/LutinApp"
"$REPO_ROOT/.build/release/lutin" build --json

echo "→ Done. DMG in $REPO_ROOT/release/"
