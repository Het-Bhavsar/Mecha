#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release_common.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENV_FILE="$TMP_DIR/version.env"
cat > "$ENV_FILE" <<'EOF'
APP_NAME=Mecha
BUNDLE_ID=com.hetbhavsar.Mecha
APP_VERSION=3.0.17
BUILD_NUMBER=18
EOF

load_release_env "$ENV_FILE"

if [[ "$(release_tag_for_env "$ENV_FILE")" != "v3.0.17" ]]; then
    echo "Expected release tag v3.0.17" >&2
    exit 1
fi

if [[ "$(release_commit_message_for_env "$ENV_FILE")" != "release: v3.0.17" ]]; then
    echo "Expected release commit message release: v3.0.17" >&2
    exit 1
fi

if [[ "$(release_zip_name_for_env "$ENV_FILE")" != "Mecha_v3.0.17.zip" ]]; then
    echo "Expected updater zip asset name Mecha_v3.0.17.zip" >&2
    exit 1
fi

if [[ "$(github_release_asset_url_for_env "$ENV_FILE" zip)" != "https://github.com/Het-Bhavsar/Mecha/releases/download/v3.0.17/Mecha_v3.0.17.zip" ]]; then
    echo "Expected GitHub release zip URL" >&2
    exit 1
fi

if [[ "$(appcast_feed_url_for_env "$ENV_FILE")" != "https://het-bhavsar.github.io/Mecha/appcast.xml" ]]; then
    echo "Expected GitHub Pages appcast URL" >&2
    exit 1
fi

if grep -Fq "bump_patch_version" "$ROOT_DIR/build_mecha.sh"; then
    echo "build_mecha.sh should not bump versions implicitly" >&2
    exit 1
fi

TMP_PREP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$TMP_PREP_DIR"' EXIT

PREP_ENV_FILE="$TMP_PREP_DIR/version.env"
PREP_PLIST_FILE="$TMP_PREP_DIR/Info.plist"
PREP_PROJECT_YML="$TMP_PREP_DIR/project.yml"
PREP_PBXPROJ_FILE="$TMP_PREP_DIR/project.pbxproj"

cat > "$PREP_ENV_FILE" <<'EOF'
APP_NAME=Mecha
APP_VERSION=1.2.3
BUILD_NUMBER=10
EOF

cat > "$PREP_PLIST_FILE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleVersion</key>
    <string>10</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.3</string>
</dict>
</plist>
EOF

cat > "$PREP_PROJECT_YML" <<'EOF'
settings:
  base:
    CURRENT_PROJECT_VERSION: 10
    MARKETING_VERSION: 1.2.3
EOF

cat > "$PREP_PBXPROJ_FILE" <<'EOF'
CURRENT_PROJECT_VERSION = 10;
MARKETING_VERSION = 1.2.3;
EOF

bash "$ROOT_DIR/scripts/prepare_release_version.sh" \
    "$PREP_ENV_FILE" \
    "$PREP_PLIST_FILE" \
    "$PREP_PROJECT_YML" \
    "$PREP_PBXPROJ_FILE"

source "$PREP_ENV_FILE"

if [[ "$APP_VERSION" != "1.2.4" ]]; then
    echo "Expected prepare_release_version.sh to bump APP_VERSION to 1.2.4" >&2
    exit 1
fi

if [[ "$BUILD_NUMBER" != "11" ]]; then
    echo "Expected prepare_release_version.sh to bump BUILD_NUMBER to 11" >&2
    exit 1
fi

unset MECHA_SIGN_MODE || true
unset MECHA_SIGN_IDENTITY || true
unset MECHA_NOTARY_PROFILE || true
unset MECHA_SIGN_CERT_P12_BASE64 || true
unset MECHA_SIGN_CERT_PASSWORD || true
unset MECHA_NOTARY_APPLE_ID || true
unset MECHA_NOTARY_TEAM_ID || true
unset MECHA_NOTARY_APP_PASSWORD || true

if [[ "$(resolve_signing_mode)" != "adhoc" ]]; then
    echo "Expected default signing mode to be adhoc" >&2
    exit 1
fi

if signing_secrets_ready; then
    echo "Signing secrets should not be ready when certificate inputs are missing" >&2
    exit 1
fi

if notarization_secrets_ready; then
    echo "Notarization secrets should not be ready when Apple inputs are missing" >&2
    exit 1
fi

if distribution_signing_ready; then
    echo "Distribution signing should not be ready without an identity" >&2
    exit 1
fi

MECHA_SIGN_IDENTITY="Developer ID Application: Example Corp (ABCD123456)"
MECHA_SIGN_CERT_P12_BASE64="ZmFrZS1jZXJ0"
MECHA_SIGN_CERT_PASSWORD="secret"
if [[ "$(resolve_signing_mode)" != "developer_id" ]]; then
    echo "Expected signing mode to switch to developer_id when identity is set" >&2
    exit 1
fi

if ! signing_secrets_ready; then
    echo "Signing secrets should be ready when identity, certificate blob, and password are set" >&2
    exit 1
fi

if ! distribution_signing_ready; then
    echo "Distribution signing should be ready when identity is set" >&2
    exit 1
fi

if notarization_ready; then
    echo "Notarization should not be ready without a notary profile" >&2
    exit 1
fi

if notarization_secrets_ready; then
    echo "Notarization secrets should not be ready without Apple notarization inputs" >&2
    exit 1
fi

MECHA_NOTARY_APPLE_ID="dev@example.com"
MECHA_NOTARY_TEAM_ID="ABCD123456"
MECHA_NOTARY_APP_PASSWORD="app-password"
if ! notarization_secrets_ready; then
    echo "Notarization secrets should be ready when Apple notarization inputs are set" >&2
    exit 1
fi

MECHA_NOTARY_PROFILE="mecha-notary"
if ! notarization_ready; then
    echo "Notarization should be ready when a notary profile is set" >&2
    exit 1
fi

echo "test_release_pipeline.sh: PASS"
