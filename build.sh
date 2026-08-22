#!/usr/bin/bash

set -euo pipefail

readonly PACKAGE_LIST="${PACKAGE_LIST:-up}"
readonly PACKAGES_JSON="${PACKAGES_JSON:-/tmp/packages.json}"
readonly MAX_REMOVALS="${MAX_REMOVALS:-50}"

read_packages() {
    local operation="$1"
    local fedora_release="$2"
    jq -r --arg list "$PACKAGE_LIST" --arg release "$fedora_release" --arg operation "$operation" '
        [(.all[$operation][$list] // [])[], (.[$release][$operation][$list] // [])[]] | unique[]
    ' "$PACKAGES_JSON"
}

load_packages() {
    local operation="$1"
    local fedora_release="$2"
    local result_name="$3"
    local output
    local -n result="$result_name"

    # Command substitution propagates read_packages/jq failure through the
    # assignment. Process substitution used directly with mapfile does not.
    if ! output="$(read_packages "$operation" "$fedora_release")"; then
        printf 'Failed to load %s packages from %s.\n' "$operation" "$PACKAGES_JSON" >&2
        return 1
    fi

    result=()
    if [[ -n "$output" ]]; then
        # ShellCheck cannot infer that this nameref updates the caller's array.
        # shellcheck disable=SC2034
        mapfile -t result <<< "$output"
    fi
}

installed_packages() {
    local package
    for package in "$@"; do
        if rpm -q --quiet -- "$package"; then
            printf '%s\n' "$package"
        fi
    done
}

remove_packages() {
    local context="$1"
    shift
    local -a requested=("$@")
    local -a installed=()

    if ((${#requested[@]} == 0)); then
        echo "No excluded packages requested during ${context}."
        return 0
    fi

    mapfile -t installed < <(installed_packages "${requested[@]}")
    if ((${#installed[@]} == 0)); then
        echo "No excluded packages are installed during ${context}."
        return 0
    fi
    if ((${#installed[@]} > MAX_REMOVALS)); then
        printf 'Refusing to remove %d packages during %s (limit: %d).\n' \
            "${#installed[@]}" "$context" "$MAX_REMOVALS" >&2
        return 1
    fi
    printf 'Removing excluded packages during %s: %s\n' "$context" "${installed[*]}"
    # Do not let a small exclusion list expand into a large dependency cleanup.
    dnf5 -y remove --no-autoremove "${installed[@]}"
}

main() {
    local fedora_release
    local -a included=()
    local -a excluded=()

    fedora_release="$(rpm -E '%fedora')"
    load_packages include "$fedora_release" included
    load_packages exclude "$fedora_release" excluded
    printf 'Packages to install: %s\n' "${included[*]:-(none)}"
    printf 'Packages to exclude: %s\n' "${excluded[*]:-(none)}"

    remove_packages "pre-install" "${excluded[@]}"
    if ((${#included[@]} > 0)); then
        dnf5 -y install "${included[@]}"
    else
        echo "No packages requested for installation."
    fi
    remove_packages "post-install verification" "${excluded[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
