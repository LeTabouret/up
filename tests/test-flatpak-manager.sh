#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config" "$test_root/data"
printf 'app.one\n' >"$test_root/config/install"
: >"$test_root/config/remove"
touch "$test_root/remote"

export TEST_LOG="$test_root/calls"
export TEST_INSTALLED="$test_root/installed"
export PATH="$test_root/bin:$PATH"
export HOME="$test_root/home"
export XDG_DATA_HOME="$test_root/data"
export FLATPAK_MANAGER_CONFIG_DIR="$test_root/config"
export FLATPAK_MANAGER_REMOTE_FILE="$test_root/remote"

# The variables in these fixtures intentionally expand when the mock executes.
# shellcheck disable=SC2016
printf '#!/usr/bin/bash\necho "notify $*" >>"$TEST_LOG"\n' >"$test_root/bin/notify-send"
# shellcheck disable=SC2016
printf '#!/usr/bin/bash\nset -eu\necho "$*" >>"$TEST_LOG"\ncase "$1" in\nremotes) exit 0 ;;\ninfo) grep -Fxq "${3:-}" "$TEST_INSTALLED" 2>/dev/null ;;\ninstall) [[ "${FAIL_INSTALL:-0}" != 1 ]] ;;\nuninstall) exit 0 ;;\n*) exit 0 ;;\nesac\n' >"$test_root/bin/flatpak"
chmod +x "$test_root/bin/flatpak" "$test_root/bin/notify-send"

manager="$repo_root/usr/libexec/ublue-user-flatpak-manager"
"$manager"
state_file="$test_root/data/ublue/flatpak-manager.sha256"
[[ -s "$state_file" ]]
first_count="$(wc -l <"$TEST_LOG")"
"$manager"
[[ "$(wc -l <"$TEST_LOG")" == "$first_count" ]]

printf 'app.one\napp.two\n' >"$test_root/config/install"
"$manager"
grep -q 'app.two' "$TEST_LOG"

before_removed_install="$(wc -l <"$TEST_LOG")"
printf 'app.one\n' >"$test_root/config/install"
"$manager"
[[ "$(wc -l <"$TEST_LOG")" -gt "$before_removed_install" ]]

printf 'remove.me\n' >"$test_root/config/remove"
printf 'remove.me\n' >"$TEST_INSTALLED"
"$manager"
grep -q 'uninstall.*remove.me' "$TEST_LOG"

printf 'app.fail\n' >>"$test_root/config/install"
old_state="$(<"$state_file")"
if FAIL_INSTALL=1 "$manager"; then
    echo "Expected failed Flatpak installation" >&2
    exit 1
fi
[[ "$(<"$state_file")" == "$old_state" ]]
"$manager"
[[ "$(<"$state_file")" != "$old_state" ]]

echo "Flatpak reconciliation tests passed."
