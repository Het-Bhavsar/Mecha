#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/version.env}"
PLIST_FILE="${2:-$ROOT_DIR/Mecha/Info.plist}"
PROJECT_YML="${3:-$ROOT_DIR/project.yml}"
PBXPROJ_FILE="${4:-$ROOT_DIR/Mecha.xcodeproj/project.pbxproj}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"

load_version_env "$ENV_FILE"

CURRENT_BUILD_NUMBER="$BUILD_NUMBER"
TARGET_BUILD_NUMBER="${MECHA_INTERNAL_BUILD_NUMBER:-}"

if [[ -z "$TARGET_BUILD_NUMBER" ]]; then
    TARGET_BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || true)"
fi

if [[ -z "$TARGET_BUILD_NUMBER" || ! "$TARGET_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Unable to determine internal release BUILD_NUMBER" >&2
    exit 1
fi

if (( TARGET_BUILD_NUMBER <= CURRENT_BUILD_NUMBER )); then
    TARGET_BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))
fi

set_build_number "$ENV_FILE" "$TARGET_BUILD_NUMBER"
sync_version_metadata "$ENV_FILE" "$PLIST_FILE" "$PROJECT_YML" "$PBXPROJ_FILE"
assert_version_metadata_synced "$ENV_FILE" "$PLIST_FILE" "$PROJECT_YML" "$PBXPROJ_FILE"

echo "[*] Prepared internal release metadata:"
echo "    APP_VERSION: $APP_VERSION"
echo "    BUILD_NUMBER: $TARGET_BUILD_NUMBER"
