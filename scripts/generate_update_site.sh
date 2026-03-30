#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/version.env}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/versioning.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release_common.sh"

load_version_env "$ENV_FILE"

ZIP_NAME="$(release_zip_name_for_env "$ENV_FILE")"
ZIP_PATH="${MECHA_UPDATE_ZIP_PATH:-$ROOT_DIR/build/$ZIP_NAME}"
SITE_DIR="${MECHA_UPDATE_SITE_DIR:-$ROOT_DIR/docs/appcast-site}"
ARCHIVE_DIR="${MECHA_UPDATE_ARCHIVE_DIR:-$ROOT_DIR/build/update-site}"
APPCAST_BIN="$(sparkle_generate_appcast_bin "$ROOT_DIR")"
DOWNLOAD_PREFIX="$(github_release_asset_url_for_env "$ENV_FILE" zip)"
DOWNLOAD_PREFIX="${DOWNLOAD_PREFIX%/$ZIP_NAME}/"
RELEASE_URL="$(github_release_url_for_env "$ENV_FILE")"
REPOSITORY_URL="$(github_repository_url_for_env "$ENV_FILE")"

if [[ ! -x "$APPCAST_BIN" ]]; then
    echo "Sparkle generate_appcast tool not found: $APPCAST_BIN" >&2
    exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Missing updater archive: $ZIP_PATH" >&2
    exit 1
fi

echo "[*] Preparing update-site staging..."
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

if [[ -d "$SITE_DIR" ]]; then
    find "$SITE_DIR" -mindepth 1 -maxdepth 1 -exec cp -R {} "$ARCHIVE_DIR/" \;
fi

cp "$ZIP_PATH" "$ARCHIVE_DIR/$ZIP_NAME"

echo "[*] Generating appcast..."
"$APPCAST_BIN" \
    --account "$(sparkle_key_account)" \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    --link "$REPOSITORY_URL" \
    --full-release-notes-url "$RELEASE_URL" \
    --maximum-deltas 0 \
    --maximum-versions 6 \
    -o "$ARCHIVE_DIR/appcast.xml" \
    "$ARCHIVE_DIR"

rm -f "$ARCHIVE_DIR/$ZIP_NAME"

mkdir -p "$SITE_DIR"
cp "$ARCHIVE_DIR/appcast.xml" "$SITE_DIR/appcast.xml"
if [[ -d "$ARCHIVE_DIR/old_updates" ]]; then
    rm -rf "$SITE_DIR/old_updates"
    cp -R "$ARCHIVE_DIR/old_updates" "$SITE_DIR/old_updates"
fi

cat > "$SITE_DIR/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Mecha Updates</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; margin: 48px auto; max-width: 720px; padding: 0 24px; color: #111827; }
    code { background: #f3f4f6; padding: 2px 6px; border-radius: 6px; }
    a { color: #2563eb; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>Mecha Update Feed</h1>
  <p>This endpoint powers internal-evaluation updates for Mecha.</p>
  <p>Feed URL: <a href="appcast.xml"><code>appcast.xml</code></a></p>
  <p>Latest release: <a href="$RELEASE_URL">$RELEASE_URL</a></p>
</body>
</html>
EOF

echo "[*] Update site ready at $SITE_DIR"
