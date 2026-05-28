#!/usr/bin/env bash
# Dev launcher for Lutin.app: builds the debug binary + packager, kills any
# running instance, repackages a fresh .app, opens it. Use this instead of
# `swift run lutin-app` — running the bare CLI binary leaves keystrokes
# attached to the terminal, and `open` on a proper .app bundle gives
# focus + Dock presence cleanly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Bootstrap Secrets.swift from template on a fresh clone. The file is
# gitignored so the real Keylight SDK key never lands in source control;
# the template ships placeholder values that compile but fail at runtime
# with a clear Keylight error, prompting the user to fill in real values.
if [[ ! -f Sources/LutinUI/Secrets.swift ]]; then
    cp Sources/LutinUI/Secrets.swift.example Sources/LutinUI/Secrets.swift
    echo "! created Sources/LutinUI/Secrets.swift from template — edit it with your Keylight SDK key before launching" >&2
fi

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
# Version comes from LutinVersion.current (the single source of truth that
# also drives `lutin --version` and release-app.sh), read straight from
# source so dev builds match the CLI without an extra `lutin` build. Build
# number is the git commit count — monotonic and matching release-app.sh.
VERSION="$(sed -n 's/.*current = "\(.*\)".*/\1/p' Sources/LutinCore/LutinVersion.swift)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
"$PRODUCT_DIR/lutin-app-packager" \
    "$PRODUCT_DIR/lutin-app" "$RES_DIR" "$OUT_DIR" \
    --name=Lutin --bundle-id=com.lutin.app --version="${VERSION:-0.0.0}" --build="$BUILD" > /dev/null
echo "   $OUT_DIR/Lutin.app (v$VERSION build $BUILD)"

# Framework embedding (KeylightSDK), the Frameworks rpath, and the
# Contents/Resources/Lutin_LutinUI.bundle asset staging are all done by
# LutinAppPackagerCore now, so this script no longer fixes them up inline —
# the same bundle the packager produces here is what `lutin release` signs.

# Re-sign with an ad-hoc signature. The packager's install_name_tool step
# invalidates the original signature, and macOS 26 enforces ad-hoc
# signatures at launch (SIGKILL — Code Signature Invalid). `--deep`
# re-signs embedded frameworks too, which is fine for local dev (release
# uses Developer ID via the real signing pipeline).
codesign --force --deep --sign - "$OUT_DIR/Lutin.app" 2>&1 \
    | grep -v "replacing existing signature" || true
echo "   re-signed (ad-hoc)"

echo "→ open"
open "$OUT_DIR/Lutin.app"
