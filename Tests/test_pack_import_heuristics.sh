#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PYTHONPATH="$ROOT_DIR${PYTHONPATH:+:$PYTHONPATH}" python3 - <<'PY'
from SoundPipeline.key_inference import build_grouped_sample_index, infer_group_for_macos_keycode

index = build_grouped_sample_index([
    "14.wav",
    "28.wav",
    "57.wav",
    "42.wav",
    "54.wav",
    "57416.wav",
    "83.wav",
    "sound.wav",
])

assert index["backspace"]["down"] == ["14.wav"]
assert index["enter"]["down"] == ["28.wav"]
assert index["space"]["down"] == ["57.wav"]
assert index["modifier_left"]["down"] == ["42.wav"]
assert index["modifier_right"]["down"] == ["54.wav"]
assert index["arrow"]["down"] == ["57416.wav"]
assert index["numpad"]["down"] == ["83.wav"]
assert index["alphanumeric"]["down"] == ["sound.wav"]

assert infer_group_for_macos_keycode(49) == "space"
assert infer_group_for_macos_keycode(51) == "backspace"
assert infer_group_for_macos_keycode(123) == "arrow"
assert infer_group_for_macos_keycode(82) == "numpad"
assert infer_group_for_macos_keycode(12) == "alphanumeric_left"
assert infer_group_for_macos_keycode(37) == "alphanumeric_right"
PY

echo "test_pack_import_heuristics.sh: PASS"
