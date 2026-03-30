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

unset MECHA_SIGN_MODE || true
unset MECHA_SIGN_IDENTITY || true
unset MECHA_NOTARY_PROFILE || true

if [[ "$(resolve_signing_mode)" != "adhoc" ]]; then
    echo "Expected default signing mode to be adhoc" >&2
    exit 1
fi

if distribution_signing_ready; then
    echo "Distribution signing should not be ready without an identity" >&2
    exit 1
fi

MECHA_SIGN_IDENTITY="Developer ID Application: Example Corp (ABCD123456)"
if [[ "$(resolve_signing_mode)" != "developer_id" ]]; then
    echo "Expected signing mode to switch to developer_id when identity is set" >&2
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

MECHA_NOTARY_PROFILE="mecha-notary"
if ! notarization_ready; then
    echo "Notarization should be ready when a notary profile is set" >&2
    exit 1
fi

echo "test_release_pipeline.sh: PASS"
