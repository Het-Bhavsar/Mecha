#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/versioning.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENV_FILE="$TMP_DIR/version.env"
PLIST_FILE="$TMP_DIR/Info.plist"
PROJECT_YML="$TMP_DIR/project.yml"
PBXPROJ_FILE="$TMP_DIR/project.pbxproj"

cat > "$ENV_FILE" <<'EOF'
APP_NAME=Mecha
BUNDLE_ID=com.hetbhavsar.Mecha
APP_VERSION=3.0.0
BUILD_NUMBER=41
EOF

cat > "$PLIST_FILE" <<'EOF'
<plist version="1.0">
<dict>
    <key>CFBundleVersion</key>
    <string>0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.0</string>
</dict>
</plist>
EOF

cat > "$PROJECT_YML" <<'EOF'
settings:
  CURRENT_PROJECT_VERSION: 0
  MARKETING_VERSION: 0.0.0
EOF

cat > "$PBXPROJ_FILE" <<'EOF'
CURRENT_PROJECT_VERSION = 0;
MARKETING_VERSION = 0.0.0;
CURRENT_PROJECT_VERSION = 0;
MARKETING_VERSION = 0.0.0;
EOF

bump_patch_version "$ENV_FILE"
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ "$APP_VERSION" != "3.0.1" ]]; then
    echo "Expected APP_VERSION=3.0.1, got $APP_VERSION" >&2
    exit 1
fi

if [[ "$BUILD_NUMBER" != "42" ]]; then
    echo "Expected BUILD_NUMBER=42, got $BUILD_NUMBER" >&2
    exit 1
fi

sync_version_metadata "$ENV_FILE" "$PLIST_FILE" "$PROJECT_YML" "$PBXPROJ_FILE"

grep -q '<string>42</string>' "$PLIST_FILE"
grep -q '<string>3.0.1</string>' "$PLIST_FILE"
grep -q 'CURRENT_PROJECT_VERSION: 42' "$PROJECT_YML"
grep -q 'MARKETING_VERSION: 3.0.1' "$PROJECT_YML"
grep -q 'CURRENT_PROJECT_VERSION = 42;' "$PBXPROJ_FILE"
grep -q 'MARKETING_VERSION = 3.0.1;' "$PBXPROJ_FILE"

DMG_NAME="$(dmg_name_for_env "$ENV_FILE")"
if [[ "$DMG_NAME" != "Mecha_v3.0.1.dmg" ]]; then
    echo "Expected Mecha_v3.0.1.dmg, got $DMG_NAME" >&2
    exit 1
fi

echo "test_versioning.sh: PASS"
