#!/bin/bash
# Mecha Distribution Release Script

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/version.env"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release_common.sh"

load_version_env "$ENV_FILE"
assert_distribution_signing_ready
assert_notarization_ready

ZIP_PATH="$ROOT_DIR/build/${APP_NAME}.zip"
DMG_PATH="$ROOT_DIR/$(dmg_name_for_env "$ENV_FILE")"

echo "[*] Building signed distribution app..."
MECHA_SIGN_MODE=developer_id bash "$ROOT_DIR/build_mecha.sh"
load_version_env "$ENV_FILE"

APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/build/${APP_NAME}.zip"
DMG_PATH="$ROOT_DIR/$(dmg_name_for_env "$ENV_FILE")"

echo "[*] Creating notarization archive..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "[*] Notarizing app archive..."
notarize_file "$ZIP_PATH"

echo "[*] Stapling app bundle..."
staple_path "$APP_BUNDLE"

echo "[*] Verifying Gatekeeper acceptance for app..."
gatekeeper_assess "$APP_BUNDLE" exec

echo "[*] Building styled DMG..."
MECHA_SIGN_MODE=developer_id bash "$ROOT_DIR/create_dmg.sh"

echo "[*] Notarizing DMG..."
notarize_file "$DMG_PATH"

echo "[*] Stapling DMG..."
staple_path "$DMG_PATH"

echo "[*] Verifying Gatekeeper acceptance for DMG..."
gatekeeper_assess "$DMG_PATH" open

echo "[*] Release complete:"
echo "    App: $APP_BUNDLE"
echo "    DMG: $DMG_PATH"
