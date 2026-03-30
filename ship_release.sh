#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$ROOT_DIR/version.env"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release_common.sh"

BRANCH="${MECHA_RELEASE_BRANCH:-$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)}"

if [[ "$BRANCH" != "main" && "${MECHA_ALLOW_NON_MAIN_RELEASE:-0}" != "1" ]]; then
    echo "Refusing to ship from branch '$BRANCH'. Switch to 'main' or set MECHA_ALLOW_NON_MAIN_RELEASE=1." >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI (gh) is required to publish the release." >&2
    exit 1
fi

echo "[*] Preparing release assets locally..."
MECHA_SKIP_GITHUB_PUBLISH=1 bash "$ROOT_DIR/release_mecha.sh"
load_version_env "$ENV_FILE"

COMMIT_MESSAGE="${MECHA_RELEASE_COMMIT_MESSAGE:-$(release_commit_message_for_env "$ENV_FILE")}"

echo "[*] Staging release changes..."
git -C "$ROOT_DIR" add -A

if git -C "$ROOT_DIR" diff --cached --quiet; then
    echo "No staged changes found for release commit." >&2
    exit 1
fi

echo "[*] Creating release commit: $COMMIT_MESSAGE"
git -C "$ROOT_DIR" commit -m "$COMMIT_MESSAGE"

echo "[*] Pushing $BRANCH to origin..."
git -C "$ROOT_DIR" push origin "$BRANCH"

echo "[*] Publishing GitHub release..."
bash "$ROOT_DIR/scripts/github_release_publish.sh" "$ENV_FILE"

echo "[*] Ship complete:"
echo "    Branch: $BRANCH"
echo "    Commit: $(git -C "$ROOT_DIR" rev-parse --short HEAD)"
echo "    Release: $(github_release_url_for_env "$ENV_FILE")"
