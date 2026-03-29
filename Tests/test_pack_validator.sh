#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

GOOD_PACK="$TMP_DIR/good-pack"
BAD_PACK="$TMP_DIR/bad-pack"
mkdir -p "$GOOD_PACK/down/alphanumeric" "$GOOD_PACK/up/alphanumeric" "$BAD_PACK/down/alphanumeric"

touch "$GOOD_PACK/down/alphanumeric/a_001.wav"
touch "$GOOD_PACK/down/alphanumeric/a_002.wav"
touch "$GOOD_PACK/up/alphanumeric/a_up_001.wav"
touch "$BAD_PACK/down/alphanumeric/a_001.wav"

cat > "$GOOD_PACK/manifest.json" <<'EOF'
{
  "manifestVersion": 2,
  "id": "good_pack",
  "name": "Good Pack",
  "brand": "Test",
  "switchType": "Linear",
  "audio": {
    "sampleRate": 48000,
    "bitDepth": 24,
    "channels": 1
  },
  "groups": {
    "alphanumeric": {
      "down": ["down/alphanumeric/a_001.wav", "down/alphanumeric/a_002.wav"],
      "up": ["up/alphanumeric/a_up_001.wav"]
    }
  },
  "fallbacks": {
    "enter": "alphanumeric"
  },
  "coverage": {
    "hasKeyUp": true,
    "groupCount": 1,
    "totalDownSamples": 2,
    "totalUpSamples": 1,
    "tier": "legacy"
  },
  "compatibility": {
    "mode": "legacy-flat"
  }
}
EOF

cat > "$BAD_PACK/manifest.json" <<'EOF'
{
  "manifestVersion": 2,
  "id": "bad_pack",
  "name": "Bad Pack",
  "brand": "Test",
  "switchType": "Linear",
  "audio": {
    "sampleRate": 48000,
    "bitDepth": 24,
    "channels": 1
  },
  "groups": {
    "alphanumeric": {
      "down": ["down/alphanumeric/a_001.wav", "down/alphanumeric/missing.wav"],
      "up": []
    }
  },
  "fallbacks": {},
  "coverage": {
    "hasKeyUp": false,
    "groupCount": 1,
    "totalDownSamples": 1,
    "totalUpSamples": 0,
    "tier": "legacy"
  }
}
EOF

python3 "$ROOT_DIR/SoundPipeline/validate_pack.py" "$GOOD_PACK"

if python3 "$ROOT_DIR/SoundPipeline/validate_pack.py" "$BAD_PACK" >/dev/null 2>&1; then
    echo "Expected validator failure for bad pack" >&2
    exit 1
fi

echo "test_pack_validator.sh: PASS"
