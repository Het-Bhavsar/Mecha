#!/bin/bash

set -euo pipefail

load_release_env() {
    local env_file="$1"
    # shellcheck disable=SC1090
    set -a
    source "$env_file"
    set +a
}

release_tag_for_env() {
    local env_file="$1"
    load_release_env "$env_file"
    printf 'v%s\n' "$APP_VERSION"
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

distribution_signing_ready() {
    [[ "$(resolve_signing_mode)" == "developer_id" ]] && [[ -n "${MECHA_SIGN_IDENTITY:-}" ]]
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
