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
# SwiftPM quietly takes only the LAST --product when several are passed
# on a single `swift build` invocation, so we issue two builds to make
# sure both the app binary and the packager are fresh.
swift build --product lutin-app > /dev/null
swift build --product lutin-app-packager > /dev/null
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

# Embed SPM-built dynamic frameworks (e.g. KeylightSDK). The packager
# doesn't do this yet; until it does, dev-app.sh handles it inline.
# Without this the bundle launches and dyld immediately aborts with
# "Library not loaded: @rpath/KeylightSDK.framework/...".
#
# TODO(packager): move framework embedding + rpath fix into
# LutinAppPackagerCore so `lutin release` produces a notarizable bundle.
APP_BIN="$OUT_DIR/Lutin.app/Contents/MacOS/Lutin"
FRAMEWORKS_DIR="$OUT_DIR/Lutin.app/Contents/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"
while IFS= read -r fw; do
    [[ -z "$fw" ]] && continue
    fw_name="$(basename "$fw")"
    rm -rf "$FRAMEWORKS_DIR/$fw_name"
    cp -R "$fw" "$FRAMEWORKS_DIR/$fw_name"
    echo "   embedded $fw_name"
done < <(find "$PRODUCT_DIR" -maxdepth 1 -type d -name "*.framework")

# Add the standard Frameworks-search rpath if missing. `install_name_tool`
# errors when the rpath is already present, so check first.
if ! otool -l "$APP_BIN" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BIN"
    echo "   added rpath @executable_path/../Frameworks"
fi

# SPM-generated `Bundle.module` for LutinUI looks for the resource
# bundle at the .app's top level — which violates macOS bundle
# structure (codesign rejects "unsealed contents in bundle root").
# Stage a parallel bundle inside `Contents/Resources/` instead, where
# both macOS and codesign are happy; LutinUI's `LutinAssets.bundle`
# accessor knows to look here.
#
# TODO(packager): bake this into LutinAppPackagerCore so `lutin release`
# also produces a bundle where module-scoped Image lookups work.
SPM_BUNDLE="$OUT_DIR/Lutin.app/Contents/Resources/Lutin_LutinUI.bundle"
mkdir -p "$SPM_BUNDLE"
cp "$OUT_DIR/Lutin.app/Contents/Resources/Assets.car" "$SPM_BUNDLE/Assets.car"
echo "   staged SPM module bundle (Contents/Resources/Lutin_LutinUI.bundle/)"

# Re-sign with an ad-hoc signature. `install_name_tool` invalidates the
# original signature, and macOS 26 enforces ad-hoc signatures at launch
# (SIGKILL — Code Signature Invalid). `--deep` re-signs embedded
# frameworks too, which is fine for local dev (release uses Developer ID
# via the real signing pipeline).
codesign --force --deep --sign - "$OUT_DIR/Lutin.app" 2>&1 \
    | grep -v "replacing existing signature" || true
echo "   re-signed (ad-hoc)"

echo "→ open"
open "$OUT_DIR/Lutin.app"
