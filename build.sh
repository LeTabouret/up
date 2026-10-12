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

verify_removal_plan() {
    local plan="$1"
    shift
    local requested
    requested="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
    jq -e --argjson requested "$requested" --argjson limit "$MAX_REMOVALS" '
        .version == "1.0" and (.rpms | type == "array") and
        (.rpms | length <= $limit) and
        all(.rpms[];
            (.nevra | capture("^(?<name>.+)-[^-]+-[^-]+\\.(?<arch>[^.]+)$") // {}) as $p |
            .action == "Remove" and ($p.name | type == "string") and ($requested | index($p.name) != null or index($p.name + "." + $p.arch) != null))
    ' "$plan" > /dev/null
}

remove_packages() {
    local context="$1"
    shift
    local -a requested=("$@")
    local -a installed=()
    local plan_dir

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
    # Resolve against installed packages, validate the complete transaction, then
    # replay exactly that plan. No ignored extras, skipped packages or autoremove.
    plan_dir="$(mktemp -d)"
    if ! dnf5 --disable-repo="*" -y remove --no-autoremove --store="$plan_dir" "${installed[@]}" ||
        ! verify_removal_plan "$plan_dir/transaction.json" "${installed[@]}"; then
        echo "Refusing unapproved removal transaction during ${context}." >&2
        rm -rf "$plan_dir"
        return 1
    fi
    if ! dnf5 --disable-repo="*" -y replay "$plan_dir"; then
        rm -rf "$plan_dir"
        return 1
    fi
    rm -rf "$plan_dir"
}

main() {
    local fedora_release
    local -a included=()
    local -a excluded=()
    local before after removed package

    fedora_release="$(rpm -E '%fedora')"
    [[ "$fedora_release" == 44 ]] || {
        echo 'Review the Fedora migration before changing the supported release (44).' >&2
        return 1
    }
    load_packages include "$fedora_release" included
    load_packages exclude "$fedora_release" excluded
    printf 'Packages to install: %s\n' "${included[*]:-(none)}"
    printf 'Packages to exclude: %s\n' "${excluded[*]:-(none)}"

    before="$(rpm -qa --queryformat '%{NAME}.%{ARCH}\n' | sort -u)"
    remove_packages "pre-install" "${excluded[@]}"
    if ((${#included[@]} > 0)); then
        dnf5 -y install "${included[@]}"
    else
        echo "No packages requested for installation."
    fi
    remove_packages "post-install verification" "${excluded[@]}"
    after="$(rpm -qa --queryformat '%{NAME}.%{ARCH}\n' | sort -u)"
    removed="$(comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        if ! printf '%s\n' "${excluded[@]}" | grep -Fxq -- "$package" && ! printf '%s\n' "${excluded[@]}" | grep -Fxq -- "${package%.*}"; then
            printf 'Unexpected dependency removal: %s. Refusing this image.\n' "$package" >&2
            return 1
        fi
    done <<< "$removed"
    for package in "${included[@]}"; do rpm -q --quiet -- "$package"; done
    for package in "${excluded[@]}"; do
        if rpm -q --quiet -- "$package"; then
            printf 'Excluded package is still installed: %s\n' "$package" >&2
            return 1
        fi
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
