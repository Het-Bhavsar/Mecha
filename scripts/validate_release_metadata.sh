#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/version.env"
PLIST_FILE="$ROOT_DIR/Mecha/Info.plist"
PROJECT_YML="$ROOT_DIR/project.yml"
PBXPROJ_FILE="$ROOT_DIR/Mecha.xcodeproj/project.pbxproj"
COMPARE_REF=""

usage() {
    echo "Usage: validate_release_metadata.sh [--require-version-change-from <git-ref>] [env_file plist_file project_yml pbxproj_file]" >&2
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --require-version-change-from)
            COMPARE_REF="${2:-}"
            if [[ -z "$COMPARE_REF" ]]; then
                usage
                exit 1
            fi
            shift 2
            ;;
        -*)
            usage
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ ${#POSITIONAL[@]} -eq 4 ]]; then
    ENV_FILE="${POSITIONAL[0]}"
    PLIST_FILE="${POSITIONAL[1]}"
    PROJECT_YML="${POSITIONAL[2]}"
    PBXPROJ_FILE="${POSITIONAL[3]}"
elif [[ ${#POSITIONAL[@]} -ne 0 ]]; then
    usage
    exit 1
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"

assert_version_metadata_synced "$ENV_FILE" "$PLIST_FILE" "$PROJECT_YML" "$PBXPROJ_FILE"

if [[ -n "$COMPARE_REF" ]]; then
    assert_release_version_changed_from_ref "$ENV_FILE" "$COMPARE_REF"
fi
