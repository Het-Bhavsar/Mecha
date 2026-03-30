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

SIGNING_MODE="$(resolve_signing_mode)"
echo "[*] Building Mecha for release ($SIGNING_MODE)..."
bash "$ROOT_DIR/build_mecha.sh"
load_version_env "$ENV_FILE"

APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
ZIP_NAME="$(release_zip_name_for_env "$ENV_FILE")"
ZIP_PATH="$ROOT_DIR/build/$ZIP_NAME"
DMG_PATH="$ROOT_DIR/$(dmg_name_for_env "$ENV_FILE")"

echo "[*] Creating updater archive..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if notarization_ready; then
    echo "[*] Notarizing app archive..."
    notarize_file "$ZIP_PATH"

    echo "[*] Stapling app bundle..."
    staple_path "$APP_BUNDLE"

    echo "[*] Verifying Gatekeeper acceptance for app..."
    gatekeeper_assess "$APP_BUNDLE" exec
else
    echo "[*] Notarization is not configured; continuing with internal-evaluation release assets."
fi

echo "[*] Building styled DMG..."
bash "$ROOT_DIR/create_dmg.sh"

if notarization_ready; then
    echo "[*] Notarizing DMG..."
    notarize_file "$DMG_PATH"

    echo "[*] Stapling DMG..."
    staple_path "$DMG_PATH"

    echo "[*] Verifying Gatekeeper acceptance for DMG..."
    gatekeeper_assess "$DMG_PATH" open
fi

echo "[*] Generating update site for GitHub Pages..."
bash "$ROOT_DIR/scripts/generate_update_site.sh" "$ENV_FILE"

if [[ "${MECHA_SKIP_GITHUB_PUBLISH:-0}" == "1" ]]; then
    echo "[*] Skipping GitHub release publishing; local release assets are ready for commit/push."
else
    echo "[*] Publishing GitHub release assets..."
    bash "$ROOT_DIR/scripts/github_release_publish.sh" "$ENV_FILE"
fi

echo "[*] Release complete:"
echo "    App: $APP_BUNDLE"
echo "    ZIP: $ZIP_PATH"
echo "    DMG: $DMG_PATH"
echo "    Appcast: $ROOT_DIR/docs/appcast-site/appcast.xml"
