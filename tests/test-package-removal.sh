#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

remove_packages empty
((${#calls[@]} == 0))

remove_packages absent missing
((${#calls[@]} == 0))

remove_packages partial installed missing partial
[[ "${calls[0]}" == "-y remove --no-autoremove installed partial" ]]

calls=()
remove_packages populated installed
[[ "${calls[0]}" == "-y remove --no-autoremove installed" ]]

many=()
for number in {1..51}; do
    many+=("pkg${number}")
done
if remove_packages ceiling "${many[@]}"; then
    echo "Expected removal ceiling to reject 51 packages" >&2
    exit 1
fi

echo "Package-removal safety tests passed."
