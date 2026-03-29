#!/bin/bash
# Mecha Unified Build Script

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/version.env"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release_common.sh"

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

SIGNING_MODE="$(resolve_signing_mode)"
echo "[*] Signing Mecha ($SIGNING_MODE)..."
codesign_bundle "$APP_BUNDLE" "$ROOT_DIR/Mecha.entitlements" "$BUNDLE_ID"

echo "[*] Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$SIGNING_MODE" == "developer_id" ]]; then
    echo "[*] Checking Gatekeeper acceptance..."
    spctl -a -vv --type exec "$APP_BUNDLE"
fi

echo "[*] Build Complete: $APP_BUNDLE"
echo "[*] Version: $APP_VERSION ($BUILD_NUMBER)"
