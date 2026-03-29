#!/bin/bash
# Mecha Unified Build Script

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/version.env"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"

bump_patch_version "$ENV_FILE"
sync_version_metadata \
    "$ENV_FILE" \
    "$ROOT_DIR/Mecha/Info.plist" \
    "$ROOT_DIR/project.yml" \
    "$ROOT_DIR/Mecha.xcodeproj/project.pbxproj"
load_version_env "$ENV_FILE"

cd "$ROOT_DIR"

BUILD_ROOT="build"
APP_BUNDLE="$BUILD_ROOT/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "[*] Targeted cleanup for persistent identity..."
# Protect the bundle directory to preserve macOS permission metadata
rm -f "$CONTENTS/MacOS/$APP_NAME"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

echo "[*] Refreshing resources..."
cp -R Mecha/Resources/* "$CONTENTS/Resources/" 2>/dev/null || true
cp Mecha/Info.plist "$CONTENTS/Info.plist"

# Support for Icon if generated
if [ -f "Mecha/Resources/Icon/AppIcon.icns" ]; then
    cp "Mecha/Resources/Icon/AppIcon.icns" "$CONTENTS/Resources/"
fi

echo "[*] Compiling Mecha (Swift)..."
swiftc -sdk $(xcrun --show-sdk-path --sdk macosx) \
    Mecha/MechaApp.swift \
    Mecha/Managers/*.swift \
    Mecha/Views/*.swift \
    -o "$CONTENTS/MacOS/$APP_NAME"

echo "[*] Hardening Identity (v2.7)..."
codesign --force --deep --sign - \
    --entitlements Mecha.entitlements \
    --identifier "$BUNDLE_ID" \
    --requirements '=designated => identifier "com.hetbhavsar.Mecha"' \
    "$APP_BUNDLE"

echo "[*] Build Complete: $APP_BUNDLE"
echo "[*] Version: $APP_VERSION ($BUILD_NUMBER)"
