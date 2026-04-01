#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENV_FILE="$TMP_DIR/version.env"
PLIST_FILE="$TMP_DIR/Info.plist"
PROJECT_YML="$TMP_DIR/project.yml"
PBXPROJ_FILE="$TMP_DIR/project.pbxproj"

cat > "$ENV_FILE" <<'EOF'
APP_NAME=Mecha
APP_VERSION=4.5.6
BUILD_NUMBER=78
EOF

cat > "$PLIST_FILE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleVersion</key>
    <string>78</string>
    <key>CFBundleShortVersionString</key>
    <string>4.5.6</string>
</dict>
</plist>
EOF

cat > "$PROJECT_YML" <<'EOF'
settings:
  base:
    CURRENT_PROJECT_VERSION: 78
    MARKETING_VERSION: 4.5.6
EOF

cat > "$PBXPROJ_FILE" <<'EOF'
CURRENT_PROJECT_VERSION = 78;
MARKETING_VERSION = 4.5.6;
EOF

bash "$ROOT_DIR/scripts/validate_release_metadata.sh" \
    "$ENV_FILE" \
    "$PLIST_FILE" \
    "$PROJECT_YML" \
    "$PBXPROJ_FILE"

cat > "$PLIST_FILE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleVersion</key>
    <string>79</string>
    <key>CFBundleShortVersionString</key>
    <string>4.5.6</string>
</dict>
</plist>
EOF

if bash "$ROOT_DIR/scripts/validate_release_metadata.sh" \
    "$ENV_FILE" \
    "$PLIST_FILE" \
    "$PROJECT_YML" \
    "$PBXPROJ_FILE"; then
    echo "Expected validate_release_metadata.sh to fail for mismatched build metadata" >&2
    exit 1
fi

echo "test_release_metadata_validation.sh: PASS"
