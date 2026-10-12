#!/usr/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export PACKAGES_JSON="${test_root}/packages.json"
printf '{"all":{"include":{"up":[]},"exclude":{"up":[]}}}\n' > "$PACKAGES_JSON"
# shellcheck disable=SC1091
source "${repo_root}/build.sh"
calls=()
rpm() {
    [[ "$1" == -q ]] || return 99
    local package="${*: -1}"
    [[ "$package" == pkg* ]] && return 0
    [[ ' installed partial ' == *" $package "* ]]
}
dnf5() {
    calls+=("$*")
    local arg dir
    local -a names=()
    for arg in "$@"; do
        if [[ "$arg" == --store=* ]]; then
            dir="${arg#--store=}"
        elif [[ "$arg" == installed || "$arg" == partial ]]; then names+=("$arg"); fi
    done
    if [[ -n "${dir:-}" ]]; then
        printf '%s\n' "${names[@]}" | jq -Rn '{version:"1.0",rpms:[inputs | {nevra:(. + "-1-1.x86_64"),action:"Remove"}]}' > "$dir/transaction.json"
    fi
}
included=(stale)
load_packages include 44 included
((${#included[@]} == 0))
printf '{broken\n' > "$PACKAGES_JSON"
if load_packages include 44 included 2> /dev/null; then exit 1; fi
remove_packages empty
remove_packages absent missing
((${#calls[@]} == 0))
remove_packages partial installed missing partial
((${#calls[@]} == 2))
[[ "${calls[0]}" == *'remove --no-autoremove --store='* ]]
[[ "${calls[1]}" == *'replay '* ]]
many=()
for n in {1..51}; do many+=("pkg$n"); done
if remove_packages ceiling "${many[@]}"; then exit 1; fi

# Exercise the real plan validator with DNF's NEVRA schema, including epoch/hyphens.
plan="$test_root/plan.json"
cat > "$plan" << 'JSON'
{"version":"1.0","rpms":[{"nevra":"gnome-search-yafti-1:1.0-1.fc44.noarch","action":"Remove"}]}
JSON
verify_removal_plan "$plan" gnome-search-yafti
verify_removal_plan "$plan" gnome-search-yafti.noarch
if verify_removal_plan "$plan" gnome-search-yafti.x86_64; then exit 1; fi
cat > "$plan" << 'JSON'
{"version":"1.0","rpms":[{"nevra":"toolbox-1-1.x86_64","action":"Remove"},{"nevra":"libFAudio-1-1.i686","action":"Remove"}]}
JSON
if verify_removal_plan "$plan" toolbox; then
    echo 'Dependency cascade accepted' >&2
    exit 1
fi
cat > "$plan" << 'JSON'
{"version":"1.0","rpms":[{"nevra":"toolbox-1-1.x86_64","action":"Install"}]}
JSON
if verify_removal_plan "$plan" toolbox; then exit 1; fi
printf '{"version":"1.0","rpms":[{"nevra":"malformed","action":"Remove"}]}\n' > "$plan"
if verify_removal_plan "$plan" toolbox; then exit 1; fi
printf '{}\n' > "$plan"
if verify_removal_plan "$plan" toolbox; then exit 1; fi

# A rejected solver plan must not reach replay.
(
    replayed=0
    dnf5() {
        local arg
        for arg in "$@"; do
            if [[ "$arg" == --store=* ]]; then
                printf '{"version":"1.0","rpms":[{"nevra":"kernel-core-1-1.x86_64","action":"Remove"}]}\n' > "${arg#--store=}/transaction.json"
            fi
            [[ "$arg" != replay ]] || replayed=1
        done
    }
    if remove_packages cascade installed; then exit 1; fi
    ((replayed == 0))
)

# Defense in depth: a replay that loses only i686 must fail the final comparison.
(
    printf '{"all":{"include":{"up":[]},"exclude":{"up":["toolbox"]}}}\n' > "$PACKAGES_JSON"
    changed=0
    rpm() {
        case "$1" in
            -E) echo 44 ;;
            -qa)
                if [[ "$*" == *'%{ARCH}'* ]]; then
                    echo libFAudio.x86_64
                    if ((changed == 0)); then printf 'toolbox.x86_64\nlibFAudio.i686\n'; fi
                else
                    echo libFAudio
                    if ((changed == 0)); then printf 'toolbox\nlibFAudio\n'; fi
                fi
                ;;
            -q) [[ "${*: -1}" == toolbox && "$changed" == 0 ]] ;;
            *) return 99 ;;
        esac
    }
    dnf5() {
        local arg
        for arg in "$@"; do
            if [[ "$arg" == --store=* ]]; then
                printf '{"version":"1.0","rpms":[{"nevra":"toolbox-1-1.x86_64","action":"Remove"}]}\n' > "${arg#--store=}/transaction.json"
            fi
            if [[ "$arg" == replay ]]; then changed=1; fi
        done
    }
    if main; then
        echo 'Multilib loss accepted' >&2
        exit 1
    fi
)
echo 'Removal preflight, exact replay and multilib safety tests passed.'
