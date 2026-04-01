#!/bin/bash
# Mecha Installer Creator (DMG)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/version.env"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release_common.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/dmg_layout.sh"
load_version_env "$ENV_FILE"

DMG_NAME="$(dmg_name_for_env "$ENV_FILE")"
STAGING_DIR="$ROOT_DIR/dmg_staging"
TEMP_DMG="$ROOT_DIR/${APP_NAME}-temp.dmg"
BACKGROUND_DIR="$STAGING_DIR/$DMG_BACKGROUND_DIR_NAME"
BACKGROUND_PATH="$BACKGROUND_DIR/$DMG_BACKGROUND_NAME"
MOUNT_DIR="/Volumes/$APP_NAME"

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
mkdir -p "$BACKGROUND_DIR"

echo "[*] Copying app to staging..."
cp -R "build/$APP_NAME.app" "$STAGING_DIR/"

echo "[*] Creating Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "[*] Generating installer background..."
create_dmg_background "$BACKGROUND_PATH"

echo "[*] Building DMG..."
rm -f "$DMG_NAME"
rm -f "$TEMP_DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TEMP_DMG"

echo "[*] Mounting writable DMG..."
if [[ -d "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
fi
hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" >/dev/null

if [[ "${MECHA_SKIP_DMG_STYLING:-0}" == "1" ]]; then
    echo "[*] Skipping Finder styling for headless build environment..."
else
    echo "[*] Styling Finder window..."
    osascript <<EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {$DMG_WINDOW_LEFT, $DMG_WINDOW_TOP, $(($DMG_WINDOW_LEFT + $DMG_WINDOW_WIDTH)), $(($DMG_WINDOW_TOP + $DMG_WINDOW_HEIGHT))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $DMG_ICON_SIZE
        set text size of viewOptions to $DMG_TEXT_SIZE
        set background picture of viewOptions to file "$DMG_BACKGROUND_DIR_NAME:$DMG_BACKGROUND_NAME"
        set position of item "$APP_NAME.app" of container window to {$DMG_APP_ICON_X, $DMG_APP_ICON_Y}
        set position of item "Applications" of container window to {$DMG_APPS_ICON_X, $DMG_APPS_ICON_Y}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
fi

sync
hdiutil detach "$MOUNT_DIR" >/dev/null

echo "[*] Compressing final DMG..."
hdiutil convert "$TEMP_DMG" -ov -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME" >/dev/null
rm -f "$TEMP_DMG"

echo "[*] Signing DMG when distribution identity is configured..."
sign_disk_image "$DMG_NAME"

echo "[*] Cleaning up..."
rm -rf "$STAGING_DIR"

echo "[*] Installer Created: $DMG_NAME"
