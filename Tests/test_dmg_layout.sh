#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/dmg_layout.sh"

if [[ "$DMG_WINDOW_WIDTH" != "640" ]]; then
    echo "Expected DMG window width to stay at 640" >&2
    exit 1
fi

if [[ "$DMG_WINDOW_HEIGHT" != "420" ]]; then
    echo "Expected DMG window height to stay at 420" >&2
    exit 1
fi

if [[ "$DMG_ICON_SIZE" != "128" ]]; then
    echo "Expected DMG icon size to stay at 128" >&2
    exit 1
fi

if [[ "$DMG_APP_ICON_X" != "170" || "$DMG_APP_ICON_Y" != "190" ]]; then
    echo "Unexpected Mecha icon position" >&2
    exit 1
fi

if [[ "$DMG_APPS_ICON_X" != "470" || "$DMG_APPS_ICON_Y" != "190" ]]; then
    echo "Unexpected Applications icon position" >&2
    exit 1
fi

if [[ "$DMG_BACKGROUND_NAME" != "dmg-background.png" ]]; then
    echo "Expected a stable DMG background asset name" >&2
    exit 1
fi

if [[ "$DMG_ARROW_CENTER_X" != "320" || "$DMG_ARROW_CENTER_Y" != "204" ]]; then
    echo "Unexpected arrow center position" >&2
    exit 1
fi

if [[ "$DMG_ARROW_TOTAL_WIDTH" != "84" ]]; then
    echo "Expected a slimmer responsive arrow width of 84" >&2
    exit 1
fi

if [[ "$DMG_ARROW_HEAD_LENGTH" != "32" ]]; then
    echo "Expected arrow head length of 32" >&2
    exit 1
fi

if [[ "$DMG_ARROW_SHAFT_HEIGHT" != "14" ]]; then
    echo "Expected slimmer arrow shaft height of 14" >&2
    exit 1
fi

if [[ "$DMG_ARROW_HEAD_HALF_HEIGHT" != "26" ]]; then
    echo "Expected arrow head half height of 26" >&2
    exit 1
fi

echo "test_dmg_layout.sh: PASS"
