#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export PACKAGES_JSON="${test_root}/packages.json"
printf '{"all":{"include":{"up":[]},"exclude":{"up":[]}}}\n' >"$PACKAGES_JSON"
# shellcheck source=../build.sh
source "${repo_root}/build.sh"

calls=()
rpm() {
    [[ "$1" == "-q" ]] || { echo "unsafe rpm invocation: $*" >&2; return 99; }
    local package="${*: -1}"
    [[ "$package" == pkg* ]] && return 0
    [[ " installed partial " == *" ${package} "* ]]
}
dnf5() { calls+=("$*"); }

included=(stale)
excluded=(stale)
load_packages include 44 included
load_packages exclude 44 excluded
((${#included[@]} == 0))
((${#excluded[@]} == 0))

printf '{ malformed json\n' >"$PACKAGES_JSON"
if load_packages include 44 included 2>/dev/null; then
    echo "Malformed packages.json unexpectedly loaded." >&2
    exit 1
fi
printf '{"all":{"include":{"up":[]},"exclude":{"up":[]}}}\n' >"$PACKAGES_JSON"

remove_packages empty
((${#calls[@]} == 0))

remove_packages absent missing
((${#calls[@]} == 0))

remove_packages partial installed missing partial
[[ "${calls[0]}" == "-y remove --no-autoremove installed partial" ]]

calls=()
remove_packages populated installed
[[ "${calls[0]}" == "-y remove --no-autoremove installed" ]]

calls=()
remove_packages several installed partial
[[ "${calls[0]}" == "-y remove --no-autoremove installed partial" ]]

many=()
for number in {1..51}; do
    many+=("pkg${number}")
done
if remove_packages ceiling "${many[@]}"; then
    echo "Expected removal ceiling to reject 51 packages" >&2
    exit 1
fi

echo "Package-removal safety tests passed."
