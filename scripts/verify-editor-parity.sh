#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

INTENTS="$REPO_ROOT/scripts/fixtures/editor-parity-intents.json"
# Use the dogfood lutin.yml as the parity baseline.
SRC="$REPO_ROOT/Apps/LutinApp/lutin.yml"

GUI_DIR="$(mktemp -d)"; CLI_DIR="$(mktemp -d)"
trap 'rm -rf "$GUI_DIR" "$CLI_DIR"' EXIT

cp "$SRC" "$GUI_DIR/lutin.yml"
cp "$SRC" "$CLI_DIR/lutin.yml"

echo "→ build"
swift build -c release --product lutin --product lutin-app-headless 2>/dev/null

echo "→ GUI replay (lutin-app-headless)"
"$REPO_ROOT/.build/release/lutin-app-headless" "$GUI_DIR/lutin.yml" "$INTENTS"

echo "→ CLI replay (lutin apply-intents)"
"$REPO_ROOT/.build/release/lutin" apply-intents \
    --config "$CLI_DIR/lutin.yml" \
    --file "$INTENTS"

echo "→ diff lutin.yml"
diff -u "$GUI_DIR/lutin.yml" "$CLI_DIR/lutin.yml"

# Background PNG render comparison is skipped here — `lutin render` does not
# exist as a top-level subcommand in this codebase. If it is added and produces
# deterministic output, uncomment the lines below.
#
# echo "→ render both"
# "$REPO_ROOT/.build/release/lutin" render --config "$GUI_DIR/lutin.yml" --output "$GUI_DIR/bg.png"
# "$REPO_ROOT/.build/release/lutin" render --config "$CLI_DIR/lutin.yml" --output "$CLI_DIR/bg.png"
#
# echo "→ diff background.png"
# cmp "$GUI_DIR/bg.png" "$CLI_DIR/bg.png"

echo "PASS"
