#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/version.env}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release_common.sh"

load_version_env "$ENV_FILE"

REPO_SLUG="$(github_repository_slug_for_env "$ENV_FILE")"
TAG="$(release_tag_for_env "$ENV_FILE")"
ZIP_NAME="$(release_zip_name_for_env "$ENV_FILE")"
ZIP_PATH="${MECHA_RELEASE_ZIP_PATH:-$ROOT_DIR/build/$ZIP_NAME}"
DMG_PATH="${MECHA_RELEASE_DMG_PATH:-$ROOT_DIR/$(dmg_name_for_env "$ENV_FILE")}"
TITLE="${APP_NAME} v${APP_VERSION}"
NOTES="${MECHA_RELEASE_NOTES:-Internal evaluation build for Mecha ${APP_VERSION}. GitHub Releases hosts the DMG and Sparkle update ZIP for existing installs.}"
TARGET="${MECHA_RELEASE_TARGET:-}"
ALLOW_EXISTING="${MECHA_RELEASE_ALLOW_EXISTING:-0}"

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Missing ZIP asset: $ZIP_PATH" >&2
    exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
    echo "Missing DMG asset: $DMG_PATH" >&2
    exit 1
fi

echo "[*] Publishing release assets to GitHub..."
if gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
    if [[ "$ALLOW_EXISTING" != "1" ]]; then
        echo "GitHub release already exists for $TAG" >&2
        exit 1
    fi

    gh release edit "$TAG" --repo "$REPO_SLUG" --title "$TITLE" --notes "$NOTES"
else
    if gh api "repos/$REPO_SLUG/git/ref/tags/$TAG" >/dev/null 2>&1 && [[ "$ALLOW_EXISTING" != "1" ]]; then
        echo "Git tag already exists for $TAG; refusing to repoint or overwrite it" >&2
        exit 1
    fi

    CREATE_ARGS=("$TAG" "--repo" "$REPO_SLUG" "--title" "$TITLE" "--notes" "$NOTES")
    if [[ -n "$TARGET" ]]; then
        CREATE_ARGS+=("--target" "$TARGET")
    fi

    gh release create "${CREATE_ARGS[@]}"
fi

gh release upload "$TAG" "$ZIP_PATH" "$DMG_PATH" --clobber --repo "$REPO_SLUG"

echo "[*] GitHub release updated: https://github.com/$REPO_SLUG/releases/tag/$TAG"
