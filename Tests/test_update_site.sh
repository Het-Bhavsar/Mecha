#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENV_FILE="$TMP_DIR/version.env"
cat > "$ENV_FILE" <<'EOF'
APP_NAME=Mecha
BUNDLE_ID=com.hetbhavsar.Mecha
GITHUB_OWNER=Het-Bhavsar
GITHUB_REPO=Mecha
APPCAST_BASE_URL=https://het-bhavsar.github.io/Mecha
SPARKLE_PUBLIC_ED_KEY=XqX/41XEIYKAzdmOXdwWmYCxOfH5Uk32AKUgOdTv75E=
APP_VERSION=9.9.9
BUILD_NUMBER=99
AUTOUPDATE_COMPATIBILITY_BUILD_FLOOR=39
EOF

APP_BUNDLE="$TMP_DIR/Mecha.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mecha</string>
    <key>CFBundleIdentifier</key>
    <string>com.hetbhavsar.Mecha</string>
    <key>CFBundleName</key>
    <string>Mecha</string>
    <key>CFBundleShortVersionString</key>
    <string>9.9.9</string>
    <key>CFBundleVersion</key>
    <string>99</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF
touch "$APP_BUNDLE/Contents/MacOS/Mecha"
chmod +x "$APP_BUNDLE/Contents/MacOS/Mecha"

ZIP_PATH="$TMP_DIR/Mecha_v9.9.9.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

SITE_DIR="$TMP_DIR/site"
ARCHIVE_DIR="$TMP_DIR/archive"

MECHA_UPDATE_SITE_DIR="$SITE_DIR" \
MECHA_UPDATE_ARCHIVE_DIR="$ARCHIVE_DIR" \
MECHA_UPDATE_ZIP_PATH="$ZIP_PATH" \
MECHA_ALLOW_UNSIGNED_APPCAST=1 \
bash "$ROOT_DIR/scripts/generate_update_site.sh" "$ENV_FILE"

if [[ ! -f "$SITE_DIR/appcast.xml" ]]; then
    echo "Expected appcast.xml to be generated" >&2
    exit 1
fi

if ! grep -Fq "https://github.com/Het-Bhavsar/Mecha/releases/download/v9.9.9/Mecha_v9.9.9.zip" "$SITE_DIR/appcast.xml"; then
    echo "Expected appcast to reference the GitHub release zip asset" >&2
    exit 1
fi

if ! grep -Fq "<link>https://github.com/Het-Bhavsar/Mecha/releases/tag/v9.9.9</link>" "$SITE_DIR/appcast.xml"; then
    echo "Expected appcast link to point at the versioned GitHub release page" >&2
    exit 1
fi

if ! grep -Fq "<sparkle:informationalUpdate>" "$SITE_DIR/appcast.xml"; then
    echo "Expected appcast to mark legacy builds as informational updates" >&2
    exit 1
fi

if ! grep -Fq "<sparkle:belowVersion>39</sparkle:belowVersion>" "$SITE_DIR/appcast.xml"; then
    echo "Expected appcast informational update floor to match AUTOUPDATE_COMPATIBILITY_BUILD_FLOOR" >&2
    exit 1
fi

echo "test_update_site.sh: PASS"
