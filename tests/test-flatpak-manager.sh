#!/usr/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config" "$test_root/data"
printf 'app.one\napp.two\n' > "$test_root/config/install"
: > "$test_root/config/remove"
touch "$test_root/remote"
export TEST_LOG="$test_root/calls"
export TEST_INSTALLED="$test_root/installed"
export TEST_SYSTEM_INSTALLED="$test_root/system-installed"
: > "$TEST_INSTALLED"
: > "$TEST_SYSTEM_INSTALLED"
export PATH="$test_root/bin:$PATH"
export XDG_DATA_HOME="$test_root/data"
export FLATPAK_MANAGER_CONFIG_DIR="$test_root/config"
export FLATPAK_MANAGER_REMOTE_FILE="$test_root/remote"
cat > "$test_root/bin/notify-send" << 'MOCK'
#!/usr/bin/bash
echo "notify $*" >> "$TEST_LOG"
MOCK
cat > "$test_root/bin/flatpak" << 'MOCK'
#!/usr/bin/bash
set -eu
echo "$*" >> "$TEST_LOG"
case "$1" in
    list)
        [[ "${FAIL_LIST:-0}" != 1 ]] || exit 1
        if [[ "$2" == --system ]]; then cat "$TEST_SYSTEM_INSTALLED"; else cat "$TEST_INSTALLED"; fi
        ;;
    info) grep -Fxq "${3:-}" "$TEST_INSTALLED" ;;
    install) [[ "${FAIL_INSTALL:-0}" != 1 ]] ;;
    uninstall) exit 0 ;;
    *) exit 0 ;;
esac
MOCK
chmod +x "$test_root/bin/flatpak" "$test_root/bin/notify-send"
manager="$repo_root/usr/libexec/ublue-user-flatpak-manager"
"$manager"
state_file="$test_root/data/ublue/flatpak-manager.sha256"
[[ -s "$state_file" ]]
grep -q 'install.*app.one.*app.two' "$TEST_LOG"
: > "$TEST_LOG"
"$manager"
[[ ! -s "$TEST_LOG" ]]

# Existing system and user applications keep their scope and origin.
printf 'app.one\n' > "$TEST_SYSTEM_INSTALLED"
printf 'app.two\nuser.unmanaged\n' > "$TEST_INSTALLED"
printf 'app.one\napp.two\napp.three\n' > "$test_root/config/install"
"$manager"
grep -Fxq 'install --user --noninteractive -- flathub app.three' "$TEST_LOG"
if grep -E '^install .*app\.(one|two)' "$TEST_LOG"; then exit 1; fi

# Removing a default does not uninstall it or any unlisted user app.
: > "$TEST_LOG"
printf 'app.one\n' > "$test_root/config/install"
"$manager"
if grep -Eq '^(install|uninstall|remote-)' "$TEST_LOG"; then exit 1; fi

# Explicit removals remain scoped to listed user apps; production list is empty.
: > "$TEST_LOG"
printf 'app.two\n' > "$test_root/config/remove"
"$manager"
grep -q '^uninstall.*app.two' "$TEST_LOG"
if grep -Eq 'uninstall.*user.unmanaged|remote-delete|remote-modify|override' "$TEST_LOG"; then exit 1; fi

# Scope-query failure must not cause duplicates or record successful state.
printf 'app.fail\n' >> "$test_root/config/install"
old_state="$(< "$state_file")"
: > "$TEST_LOG"
if FAIL_LIST=1 "$manager"; then
    echo 'Scope-query failure accepted.' >&2
    exit 1
fi
[[ "$(< "$state_file")" == "$old_state" ]]
if grep -Eq '^(install|uninstall|remote-)' "$TEST_LOG"; then exit 1; fi

if FAIL_INSTALL=1 "$manager"; then
    echo 'Install failure accepted.' >&2
    exit 1
fi
[[ "$(< "$state_file")" == "$old_state" ]]
"$manager"
[[ "$(< "$state_file")" != "$old_state" ]]
echo 'Flatpak scope, preservation and retry tests passed.'
