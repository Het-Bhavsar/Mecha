#!/bin/bash
# Mecha Installer Creator (DMG)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/version.env"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
load_version_env "$ENV_FILE"

DMG_NAME="$(dmg_name_for_env "$ENV_FILE")"
STAGING_DIR="$ROOT_DIR/dmg_staging"

cd "$ROOT_DIR"

echo "[*] Ensuring build exists..."
if [ ! -d "build/$APP_NAME.app" ]; then
    ./build_mecha.sh
    load_version_env "$ENV_FILE"
    DMG_NAME="$(dmg_name_for_env "$ENV_FILE")"
fi

echo "[*] Preparing staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "[*] Copying app to staging..."
cp -R "build/$APP_NAME.app" "$STAGING_DIR/"

echo "[*] Creating Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "[*] Building DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

echo "[*] Cleaning up..."
rm -rf "$STAGING_DIR"

echo "[*] Installer Created: $DMG_NAME"
