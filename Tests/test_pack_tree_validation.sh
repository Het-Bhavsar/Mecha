#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACK_ROOT="$ROOT_DIR/Mecha/Resources/SoundPacks"
VALIDATOR="$ROOT_DIR/SoundPipeline/validate_pack.py"

failed=0

while IFS= read -r -d '' pack_dir; do
  if ! python3 "$VALIDATOR" "$pack_dir"; then
    failed=1
  fi
done < <(find "$PACK_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [[ "$failed" -ne 0 ]]; then
  echo "[test_pack_tree_validation] One or more packs failed validation" >&2
  exit 1
fi

echo "[test_pack_tree_validation] PASS"
