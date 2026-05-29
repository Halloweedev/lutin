#!/usr/bin/env bash
# Builds Lutin.app, assembles it into a .app via LutinAppPackager, then
# releases it using lutin itself (dogfood).
#
# Set LUTIN_UNSIGNED_DOGFOOD=1 to run the unsigned `lutin build --json` path
# instead of the real signed/notarized `lutin release --json` path.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Bootstrap Apps/LutinApp/lutin.yml from template on a fresh clone. The
# real file is gitignored because it embeds a personal signing identity
# and notary profile name; the template ships placeholder values that
# `lutin doctor` will flag, prompting the user to fill in their own.
if [[ ! -f Apps/LutinApp/lutin.yml ]]; then
    cp Apps/LutinApp/lutin.yml.example Apps/LutinApp/lutin.yml
    echo "! created Apps/LutinApp/lutin.yml from template — edit it with your Developer ID signing identity and notarytool profile before releasing" >&2
fi

# Build number = git commit count: monotonic, deterministic, no manual
# bumping. CFBundleVersion must increase across releases for Sparkle and
# notarization hygiene; commit count does that for free. Override with
# LUTIN_BUILD; falls back to 1 outside a git checkout (e.g. tarball build).
BUILD="${LUTIN_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

echo "→ swift build -c release"
# Build each product in its own invocation. A single
# `swift build --product A --product B --product C` only actually builds the
# LAST `--product` (SwiftPM quirk), which silently leaves the others stale —
# e.g. an old `lutin` whose `--version` predates a release, breaking the
# VERSION read below. Separate invocations force all three current.
swift build -c release --product lutin
swift build -c release --product lutin-app
swift build -c release --product lutin-app-packager
PRODUCT_DIR="$(swift build --show-bin-path -c release)"

echo "→ Resolve resource bundle"
BIN="$PRODUCT_DIR/lutin-app"
PACKAGER="$PRODUCT_DIR/lutin-app-packager"
LUTIN="$PRODUCT_DIR/lutin"

# Single source of truth for the version: LutinVersion.current, read back
# from the freshly-built CLI (`lutin --version`). Keeps the GUI app bundle
# version locked to the CLI version so the two can't drift. Override with
# LUTIN_VERSION only for one-off local builds.
VERSION="${LUTIN_VERSION:-$("$LUTIN" --version)}"
echo "  version: $VERSION (build $BUILD)"
RES_DIR="$(find "$PRODUCT_DIR" -maxdepth 1 -type d -name '*LutinUI*.bundle' -print -quit)"
if [[ -z "$RES_DIR" ]]; then
  echo "ERROR: could not locate the LutinUI resource bundle under $PRODUCT_DIR" >&2
  echo "       (expected something like Lutin_LutinUI.bundle)" >&2
  exit 1
fi
echo "  bundle: $RES_DIR"

echo "→ Assemble Lutin.app"
OUT_DIR="$REPO_ROOT/Apps/LutinApp/build"
mkdir -p "$OUT_DIR"
"$PACKAGER" \
    "$BIN" "$RES_DIR" "$OUT_DIR" \
    --name=Lutin --bundle-id=com.lutin.app \
    --version="$VERSION" --build="$BUILD"

cd "$REPO_ROOT/Apps/LutinApp"
if [[ "${LUTIN_UNSIGNED_DOGFOOD:-0}" == "1" ]]; then
    echo "→ Build unsigned DMG with lutin (dogfood)"
    "$LUTIN" build --json
else
    echo "→ Release with lutin (dogfood)"
    "$LUTIN" release --json
fi

echo "→ Done. DMG in $REPO_ROOT/release/"
