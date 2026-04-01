#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
    echo "Working tree has uncommitted changes. Commit or stash them before syncing." >&2
    exit 1
fi

git -C "$ROOT_DIR" fetch origin --tags
git -C "$ROOT_DIR" checkout main
git -C "$ROOT_DIR" pull --ff-only origin main
