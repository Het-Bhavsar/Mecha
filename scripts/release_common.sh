#!/bin/bash

set -euo pipefail

load_release_env() {
    local env_file="$1"
    # shellcheck disable=SC1090
    set -a
    source "$env_file"
    set +a
}

sparkle_vendor_root() {
    local root_dir="$1"
    printf '%s/vendor/Sparkle/sparkle-spm\n' "$root_dir"
}

sparkle_framework_path() {
    local root_dir="$1"
    printf '%s/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework\n' "$(sparkle_vendor_root "$root_dir")"
}

sparkle_framework_parent() {
    local root_dir="$1"
    printf '%s/Sparkle.xcframework/macos-arm64_x86_64\n' "$(sparkle_vendor_root "$root_dir")"
}

sparkle_generate_appcast_bin() {
    local root_dir="$1"
    printf '%s/bin/generate_appcast\n' "$(sparkle_vendor_root "$root_dir")"
}

sparkle_key_account() {
    printf '%s\n' "${MECHA_SPARKLE_KEY_ACCOUNT:-ed25519}"
}

github_owner_for_env() {
    local env_file="$1"
    load_release_env "$env_file"
    printf '%s\n' "${GITHUB_OWNER:-Het-Bhavsar}"
}

github_repo_for_env() {
    local env_file="$1"
    load_release_env "$env_file"
    printf '%s\n' "${GITHUB_REPO:-Mecha}"
}

release_tag_for_env() {
    local env_file="$1"
    load_release_env "$env_file"
    printf 'v%s\n' "$APP_VERSION"
}

release_commit_message_for_env() {
    local env_file="$1"
    printf 'release: %s\n' "$(release_tag_for_env "$env_file")"
}

release_zip_name_for_env() {
    local env_file="$1"
    load_release_env "$env_file"
    printf '%s_v%s.zip\n' "$APP_NAME" "$APP_VERSION"
}

appcast_feed_url_for_env() {
    local env_file="$1"
    load_release_env "$env_file"

    local base_url="${APPCAST_BASE_URL:-https://het-bhavsar.github.io/Mecha}"
    base_url="${base_url%/}"
    printf '%s/appcast.xml\n' "$base_url"
}

github_release_asset_url_for_env() {
    local env_file="$1"
    local asset_kind="$2"
    local owner repo tag asset_name

    owner="$(github_owner_for_env "$env_file")"
    repo="$(github_repo_for_env "$env_file")"
    tag="$(release_tag_for_env "$env_file")"

    case "$asset_kind" in
        zip)
            asset_name="$(release_zip_name_for_env "$env_file")"
            ;;
        *)
            echo "Unsupported asset kind: $asset_kind" >&2
            return 1
            ;;
    esac

    printf 'https://github.com/%s/%s/releases/download/%s/%s\n' "$owner" "$repo" "$tag" "$asset_name"
}

github_repository_slug_for_env() {
    local env_file="$1"
    printf '%s/%s\n' "$(github_owner_for_env "$env_file")" "$(github_repo_for_env "$env_file")"
}

github_release_url_for_env() {
    local env_file="$1"
    printf 'https://github.com/%s/releases/tag/%s\n' "$(github_repository_slug_for_env "$env_file")" "$(release_tag_for_env "$env_file")"
}

github_repository_url_for_env() {
    local env_file="$1"
    printf 'https://github.com/%s\n' "$(github_repository_slug_for_env "$env_file")"
}

resolve_signing_mode() {
    local requested="${MECHA_SIGN_MODE:-}"

    if [[ -n "$requested" ]]; then
        case "$requested" in
            adhoc|developer_id)
                printf '%s\n' "$requested"
                return 0
                ;;
            *)
                echo "Unsupported MECHA_SIGN_MODE: $requested" >&2
                return 1
                ;;
        esac
    fi

    if [[ -n "${MECHA_SIGN_IDENTITY:-}" ]]; then
        printf 'developer_id\n'
    else
        printf 'adhoc\n'
    fi
}

signing_secrets_ready() {
    [[ -n "${MECHA_SIGN_IDENTITY:-}" ]] && \
    [[ -n "${MECHA_SIGN_CERT_P12_BASE64:-}" ]] && \
    [[ -n "${MECHA_SIGN_CERT_PASSWORD:-}" ]]
}

notarization_secrets_ready() {
    signing_secrets_ready && \
    [[ -n "${MECHA_NOTARY_APPLE_ID:-}" ]] && \
    [[ -n "${MECHA_NOTARY_TEAM_ID:-}" ]] && \
    [[ -n "${MECHA_NOTARY_APP_PASSWORD:-}" ]]
}

distribution_signing_ready() {
    [[ "$(resolve_signing_mode)" == "developer_id" ]] && [[ -n "${MECHA_SIGN_IDENTITY:-}" ]]
}

update_site_generation_ready() {
    if [[ "${MECHA_SKIP_UPDATE_SITE:-0}" == "1" ]]; then
        return 1
    fi

    if [[ "${MECHA_ALLOW_UNSIGNED_APPCAST:-0}" == "1" ]]; then
        return 0
    fi

    distribution_signing_ready
}

notarization_ready() {
    distribution_signing_ready && [[ -n "${MECHA_NOTARY_PROFILE:-}" ]]
}

assert_distribution_signing_ready() {
    if distribution_signing_ready; then
        return 0
    fi

    cat >&2 <<'EOF'
Distribution signing is not configured.

Set:
- MECHA_SIGN_MODE=developer_id
- MECHA_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

Then rerun the release command.
EOF
    return 1
}

assert_notarization_ready() {
    if notarization_ready; then
        return 0
    fi

    cat >&2 <<'EOF'
Notarization is not configured.

Set:
- MECHA_SIGN_MODE=developer_id
- MECHA_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
- MECHA_NOTARY_PROFILE=<stored notarytool profile name>

Create the profile once with:
  xcrun notarytool store-credentials <profile-name> --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>
EOF
    return 1
}

signing_identity_available() {
    local identity="${MECHA_SIGN_IDENTITY:-}"

    [[ -n "$identity" ]] || return 1
    security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$identity"
}

codesign_bundle() {
    local bundle_path="$1"
    local entitlements_file="$2"
    local identifier="$3"
    local mode
    mode="$(resolve_signing_mode)"

    if [[ "$mode" == "developer_id" ]]; then
        if ! signing_identity_available; then
            echo "Developer ID identity not found in keychain: ${MECHA_SIGN_IDENTITY:-<unset>}" >&2
            return 1
        fi

        codesign --force \
            --sign "$MECHA_SIGN_IDENTITY" \
            --timestamp \
            --options runtime \
            --entitlements "$entitlements_file" \
            --identifier "$identifier" \
            "$bundle_path"
    else
        codesign --force \
            --sign - \
            --entitlements "$entitlements_file" \
            --identifier "$identifier" \
            "$bundle_path"
    fi
}

sign_disk_image() {
    local dmg_path="$1"

    if ! distribution_signing_ready; then
        return 0
    fi

    if ! signing_identity_available; then
        echo "Developer ID identity not found in keychain: ${MECHA_SIGN_IDENTITY:-<unset>}" >&2
        return 1
    fi

    codesign --force \
        --sign "$MECHA_SIGN_IDENTITY" \
        --timestamp \
        "$dmg_path"
}

sign_embedded_sparkle_framework() {
    local framework_path="$1"
    local current_path installer_path downloader_path autoupdate_path updater_app_path
    local mode

    [[ -d "$framework_path" ]] || return 0

    mode="$(resolve_signing_mode)"
    current_path="$framework_path/Versions/Current"
    installer_path="$current_path/XPCServices/Installer.xpc"
    downloader_path="$current_path/XPCServices/Downloader.xpc"
    autoupdate_path="$current_path/Autoupdate"
    updater_app_path="$current_path/Updater.app"

    if [[ "$mode" == "developer_id" ]] && ! signing_identity_available; then
        echo "Developer ID identity not found in keychain: ${MECHA_SIGN_IDENTITY:-<unset>}" >&2
        return 1
    fi

    if [[ -e "$installer_path" ]]; then
        if [[ "$mode" == "developer_id" ]]; then
            codesign --force --sign "$MECHA_SIGN_IDENTITY" --timestamp --options runtime "$installer_path"
        else
            codesign --force --sign - "$installer_path"
        fi
    fi

    if [[ -e "$downloader_path" ]]; then
        if [[ "$mode" == "developer_id" ]]; then
            codesign --force --sign "$MECHA_SIGN_IDENTITY" --timestamp --options runtime --preserve-metadata=entitlements "$downloader_path"
        else
            codesign --force --sign - --preserve-metadata=entitlements "$downloader_path"
        fi
    fi

    if [[ -e "$autoupdate_path" ]]; then
        if [[ "$mode" == "developer_id" ]]; then
            codesign --force --sign "$MECHA_SIGN_IDENTITY" --timestamp --options runtime "$autoupdate_path"
        else
            codesign --force --sign - "$autoupdate_path"
        fi
    fi

    if [[ -e "$updater_app_path" ]]; then
        if [[ "$mode" == "developer_id" ]]; then
            codesign --force --sign "$MECHA_SIGN_IDENTITY" --timestamp --options runtime "$updater_app_path"
        else
            codesign --force --sign - "$updater_app_path"
        fi
    fi

    if [[ "$mode" == "developer_id" ]]; then
        codesign --force --sign "$MECHA_SIGN_IDENTITY" --timestamp --options runtime "$framework_path"
    else
        codesign --force --sign - "$framework_path"
    fi
}

notarize_file() {
    local file_path="$1"
    assert_notarization_ready
    xcrun notarytool submit "$file_path" --keychain-profile "$MECHA_NOTARY_PROFILE" --wait
}

staple_path() {
    local path="$1"
    xcrun stapler staple "$path"
}

gatekeeper_assess() {
    local path="$1"
    local kind="$2"
    spctl -a -vv --type "$kind" "$path"
}
