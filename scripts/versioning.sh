#!/bin/bash

set -euo pipefail

load_version_env() {
    local env_file="$1"
    # shellcheck disable=SC1090
    set -a
    source "$env_file"
    set +a
}

persist_env_value() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    if grep -q "^${key}=" "$env_file"; then
        perl -0pi -e "s/^${key}=.*\$/${key}=${value}/m" "$env_file"
    else
        printf '\n%s=%s\n' "$key" "$value" >> "$env_file"
    fi
}

bump_patch_version() {
    local env_file="$1"

    load_version_env "$env_file"

    local major minor patch
    IFS='.' read -r major minor patch <<< "$APP_VERSION"

    APP_VERSION="${major}.${minor}.$((patch + 1))"
    BUILD_NUMBER="$((BUILD_NUMBER + 1))"

    persist_env_value "$env_file" "APP_VERSION" "$APP_VERSION"
    persist_env_value "$env_file" "BUILD_NUMBER" "$BUILD_NUMBER"
}

sync_version_metadata() {
    local env_file="$1"
    local plist_file="$2"
    local project_yml="$3"
    local pbxproj_file="$4"

    load_version_env "$env_file"

    APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" perl -0pi -e '
        s#(<key>CFBundleVersion</key>\s*<string>).*?(</string>)#$1$ENV{BUILD_NUMBER}$2#s;
        s#(<key>CFBundleShortVersionString</key>\s*<string>).*?(</string>)#$1$ENV{APP_VERSION}$2#s;
    ' "$plist_file"

    APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" perl -0pi -e '
        s/(CURRENT_PROJECT_VERSION:\s*).*/${1}$ENV{BUILD_NUMBER}/g;
        s/(MARKETING_VERSION:\s*).*/${1}$ENV{APP_VERSION}/g;
    ' "$project_yml"

    APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" perl -0pi -e '
        s/(CURRENT_PROJECT_VERSION = )[^;]+;/${1}$ENV{BUILD_NUMBER};/g;
        s/(MARKETING_VERSION = )[^;]+;/${1}$ENV{APP_VERSION};/g;
    ' "$pbxproj_file"
}

dmg_name_for_env() {
    local env_file="$1"

    load_version_env "$env_file"
    printf '%s_v%s.dmg\n' "$APP_NAME" "$APP_VERSION"
}
