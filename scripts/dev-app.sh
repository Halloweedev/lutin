#!/usr/bin/env bash
# Dev launcher for Lutin.app: builds the debug binary + packager, kills any
# running instance, repackages a fresh .app, opens it. Use this instead of
# `swift run lutin-app` — running the bare CLI binary leaves keystrokes
# attached to the terminal, and `open` on a proper .app bundle gives
# focus + Dock presence cleanly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "→ build (debug)"
swift build --product lutin-app --product lutin-app-packager > /dev/null
PRODUCT_DIR="$(swift build --show-bin-path -c debug)"

echo "→ kill existing instances"
pkill -9 -f "MacOS/Lutin" 2>/dev/null || true
sleep 1

echo "→ assemble Lutin.app"
RES_DIR="$(find "$PRODUCT_DIR" -maxdepth 1 -name "*LutinUI*.bundle" -type d -print -quit)"
if [[ -z "$RES_DIR" ]]; then
    echo "could not find a LutinUI resource bundle under $PRODUCT_DIR" >&2
    exit 1
fi
OUT_DIR="$REPO_ROOT/Apps/LutinApp/build"
rm -rf "$OUT_DIR/Lutin.app"
mkdir -p "$OUT_DIR"
"$PRODUCT_DIR/lutin-app-packager" \
    "$PRODUCT_DIR/lutin-app" "$RES_DIR" "$OUT_DIR" \
    --name=Lutin --bundle-id=com.lutin.app --version=0.1.0 --build=1 > /dev/null
echo "   $OUT_DIR/Lutin.app"

echo "→ open"
open "$OUT_DIR/Lutin.app"
