#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/version.env}"
PLIST_FILE="${2:-$ROOT_DIR/Mecha/Info.plist}"
PROJECT_YML="${3:-$ROOT_DIR/project.yml}"
PBXPROJ_FILE="${4:-$ROOT_DIR/Mecha.xcodeproj/project.pbxproj}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"

bump_patch_version "$ENV_FILE"
sync_version_metadata "$ENV_FILE" "$PLIST_FILE" "$PROJECT_YML" "$PBXPROJ_FILE"
assert_version_metadata_synced "$ENV_FILE" "$PLIST_FILE" "$PROJECT_YML" "$PBXPROJ_FILE"
