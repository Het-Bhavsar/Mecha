#!/bin/bash

set -euo pipefail

DMG_WINDOW_LEFT=160
DMG_WINDOW_TOP=120
DMG_WINDOW_WIDTH=640
DMG_WINDOW_HEIGHT=420
DMG_ICON_SIZE=128
DMG_TEXT_SIZE=16
DMG_APP_ICON_X=170
DMG_APP_ICON_Y=190
DMG_APPS_ICON_X=470
DMG_APPS_ICON_Y=190
DMG_ARROW_CENTER_X=$(( (DMG_APP_ICON_X + DMG_APPS_ICON_X) / 2 ))
DMG_ARROW_CENTER_Y=$(( DMG_APP_ICON_Y + 14 ))
DMG_ARROW_TOTAL_WIDTH=$(( (DMG_APPS_ICON_X - DMG_APP_ICON_X) * 28 / 100 ))
DMG_ARROW_HEAD_LENGTH=$(( DMG_ICON_SIZE / 4 ))
DMG_ARROW_SHAFT_HEIGHT=$(( DMG_ICON_SIZE / 9 ))
DMG_ARROW_HEAD_HALF_HEIGHT=$(( DMG_ICON_SIZE / 5 + 1 ))
DMG_BACKGROUND_DIR_NAME=".background"
DMG_BACKGROUND_NAME="dmg-background.png"

create_dmg_background() {
    local output_path="$1"
    mkdir -p "$(dirname "$output_path")"

    python3 - \
        "$output_path" \
        "$DMG_WINDOW_WIDTH" \
        "$DMG_WINDOW_HEIGHT" \
        "$DMG_ARROW_CENTER_X" \
        "$DMG_ARROW_CENTER_Y" \
        "$DMG_ARROW_TOTAL_WIDTH" \
        "$DMG_ARROW_HEAD_LENGTH" \
        "$DMG_ARROW_SHAFT_HEIGHT" \
        "$DMG_ARROW_HEAD_HALF_HEIGHT" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFilter

target = sys.argv[1]
width = int(sys.argv[2])
height = int(sys.argv[3])
arrow_center_x = int(sys.argv[4])
arrow_center_y = int(sys.argv[5])
arrow_total_width = int(sys.argv[6])
arrow_head_length = int(sys.argv[7])
arrow_shaft_height = int(sys.argv[8])
arrow_head_half_height = int(sys.argv[9])

canvas = Image.new("RGBA", (width, height), (248, 248, 250, 255))
draw = ImageDraw.Draw(canvas)

# Subtle top edge so the white field still feels like a deliberate installer surface.
draw.rectangle((0, 0, width, 28), fill=(242, 242, 245, 255))
draw.line((0, 28, width, 28), fill=(225, 225, 229, 255), width=1)

arrow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
arrow_draw = ImageDraw.Draw(arrow)

arrow_left = arrow_center_x - arrow_total_width // 2
arrow_right = arrow_center_x + arrow_total_width // 2
arrow_head_start = arrow_right - arrow_head_length
shaft_top = arrow_center_y - arrow_shaft_height // 2
shaft_bottom = shaft_top + arrow_shaft_height
shaft_radius = max(1, arrow_shaft_height // 2)

arrow_draw.rounded_rectangle(
    (arrow_left, shaft_top, arrow_head_start, shaft_bottom),
    radius=shaft_radius,
    fill=(220, 222, 227, 220),
)
arrow_draw.polygon(
    [
        (arrow_head_start - 3, arrow_center_y - arrow_head_half_height),
        (arrow_right, arrow_center_y),
        (arrow_head_start - 3, arrow_center_y + arrow_head_half_height),
    ],
    fill=(220, 222, 227, 220),
)
arrow = arrow.filter(ImageFilter.GaussianBlur(radius=0.25))
canvas.alpha_composite(arrow)

shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.ellipse((78, 300, 250, 328), fill=(0, 0, 0, 20))
shadow_draw.ellipse((390, 300, 562, 328), fill=(0, 0, 0, 20))
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=7))
canvas.alpha_composite(shadow)

canvas.save(target, "PNG")
PY
}
