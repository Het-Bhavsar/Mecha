#!/bin/bash

set -euo pipefail

load_version_env() {
    local env_file="$1"
    # shellcheck disable=SC1090
    set -a
    source "$env_file"
    set +a
}

env_value_for_key() {
    local env_file="$1"
    local key="$2"

    sed -n "s/^${key}=//p" "$env_file" | head -n 1
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

set_build_number() {
    local env_file="$1"
    local build_number="$2"

    if [[ -z "$build_number" || ! "$build_number" =~ ^[0-9]+$ ]]; then
        echo "Invalid BUILD_NUMBER: $build_number" >&2
        return 1
    fi

    persist_env_value "$env_file" "BUILD_NUMBER" "$build_number"
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

plist_string_value() {
    local plist_file="$1"
    local key="$2"

    perl -0ne '
        my $key = $ENV{MECHA_PLIST_KEY};
        if (m#<key>\Q$key\E</key>\s*<string>(.*?)</string>#s) {
            print "$1\n";
            exit 0;
        }
        exit 1;
    ' "$plist_file"
}

project_yml_value() {
    local project_yml="$1"
    local key="$2"

    perl -ne '
        my $key = $ENV{MECHA_PROJECT_KEY};
        our $found = 0;
        if (/^\s*\Q$key\E:\s*(\S+)\s*$/) {
            $found = 1;
            print "$1\n";
            exit 0;
        }
        END {
            exit 1 if !$found;
        }
    ' "$project_yml"
}

pbxproj_unique_value() {
    local pbxproj_file="$1"
    local key="$2"

    perl -ne '
        my $key = $ENV{MECHA_PBXPROJ_KEY};
        while (/\Q$key\E = ([^;]+);/g) {
            $values{$1} = 1;
        }
        END {
            my @values = sort keys %values;
            exit 1 if scalar(@values) == 0;
            exit 2 if scalar(@values) > 1;
            print "$values[0]\n";
        }
    ' "$pbxproj_file"
}

assert_version_metadata_synced() {
    local env_file="$1"
    local plist_file="$2"
    local project_yml="$3"
    local pbxproj_file="$4"
    local env_version env_build plist_version plist_build project_version project_build pbxproj_version pbxproj_build

    env_version="$(env_value_for_key "$env_file" "APP_VERSION")"
    env_build="$(env_value_for_key "$env_file" "BUILD_NUMBER")"

    if [[ -z "$env_version" || -z "$env_build" ]]; then
        echo "Missing APP_VERSION or BUILD_NUMBER in $env_file" >&2
        return 1
    fi

    plist_version="$(MECHA_PLIST_KEY="CFBundleShortVersionString" plist_string_value "$plist_file" "CFBundleShortVersionString")"
    plist_build="$(MECHA_PLIST_KEY="CFBundleVersion" plist_string_value "$plist_file" "CFBundleVersion")"
    project_version="$(MECHA_PROJECT_KEY="MARKETING_VERSION" project_yml_value "$project_yml" "MARKETING_VERSION")"
    project_build="$(MECHA_PROJECT_KEY="CURRENT_PROJECT_VERSION" project_yml_value "$project_yml" "CURRENT_PROJECT_VERSION")"
    pbxproj_version="$(MECHA_PBXPROJ_KEY="MARKETING_VERSION" pbxproj_unique_value "$pbxproj_file" "MARKETING_VERSION")"
    pbxproj_build="$(MECHA_PBXPROJ_KEY="CURRENT_PROJECT_VERSION" pbxproj_unique_value "$pbxproj_file" "CURRENT_PROJECT_VERSION")"

    if [[ "$env_version" != "$plist_version" || "$env_version" != "$project_version" || "$env_version" != "$pbxproj_version" ]]; then
        cat >&2 <<EOF
Version metadata mismatch detected:
- version.env APP_VERSION=$env_version
- Info.plist CFBundleShortVersionString=$plist_version
- project.yml MARKETING_VERSION=$project_version
- project.pbxproj MARKETING_VERSION=$pbxproj_version
EOF
        return 1
    fi

    if [[ "$env_build" != "$plist_build" || "$env_build" != "$project_build" || "$env_build" != "$pbxproj_build" ]]; then
        cat >&2 <<EOF
Build metadata mismatch detected:
- version.env BUILD_NUMBER=$env_build
- Info.plist CFBundleVersion=$plist_build
- project.yml CURRENT_PROJECT_VERSION=$project_build
- project.pbxproj CURRENT_PROJECT_VERSION=$pbxproj_build
EOF
        return 1
    fi
}

assert_release_version_changed_from_ref() {
    local env_file="$1"
    local git_ref="$2"
    local repo_root env_relative_path current_version current_build base_version base_build

    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$repo_root" ]]; then
        echo "validate_release_metadata: not inside a git repository" >&2
        return 1
    fi

    case "$env_file" in
        "$repo_root"/*)
            env_relative_path="${env_file#$repo_root/}"
            ;;
        *)
            echo "validate_release_metadata: --require-version-change-from only supports repository-tracked env files" >&2
            return 1
            ;;
    esac

    current_version="$(env_value_for_key "$env_file" "APP_VERSION")"
    current_build="$(env_value_for_key "$env_file" "BUILD_NUMBER")"
    base_version="$(git show "$git_ref:$env_relative_path" | sed -n 's/^APP_VERSION=//p' | head -n 1)"
    base_build="$(git show "$git_ref:$env_relative_path" | sed -n 's/^BUILD_NUMBER=//p' | head -n 1)"

    if [[ -z "$base_version" || -z "$base_build" ]]; then
        echo "Unable to read APP_VERSION or BUILD_NUMBER from $git_ref:$env_relative_path" >&2
        return 1
    fi

    if [[ "$current_version" == "$base_version" ]]; then
        echo "APP_VERSION did not change relative to $git_ref (still $current_version)" >&2
        return 1
    fi

    if [[ "$current_build" == "$base_build" ]]; then
        echo "BUILD_NUMBER did not change relative to $git_ref (still $current_build)" >&2
        return 1
    fi
}

dmg_name_for_env() {
    local env_file="$1"

    load_version_env "$env_file"
    printf '%s_v%s.dmg\n' "$APP_NAME" "$APP_VERSION"
}
