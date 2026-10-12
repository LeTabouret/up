#!/usr/bin/bash
set -euo pipefail
image="${1:?Usage: tests/image-smoke.sh IMAGE}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base="$(awk '/^FROM ghcr.io\/ublue-os\/bazzite-gnome:/ {print $2}' "$repo_root/Containerfile")"
# PODMAN_ROOT/RUNROOT allow verification in isolated temporary storage.
podman_args=()
if [[ -n "${PODMAN_ROOT:-}" ]]; then
    podman_args+=(--root "$PODMAN_ROOT" --runroot "${PODMAN_RUNROOT:?}")
fi
podman "${podman_args[@]}" run --rm --pull=never --network=none --entrypoint bash "$image" -euc '
    test "$(readlink /etc/systemd/system/dmemcg-booster-system.service)" = /dev/null
    test "$(readlink /etc/systemd/user/dmemcg-booster-user.service)" = /dev/null
    /usr/bin/up-steam-diagnostics --help >/dev/null
    /usr/libexec/up-verify-image
'
podman "${podman_args[@]}" image inspect "$image" | jq -e '
    .[0].Config.Labels |
    .["containers.bootc"] == "1" and
    .["org.opencontainers.image.title"] == "Up" and
    (.["org.opencontainers.image.version"] | length > 0) and
    (.["org.opencontainers.image.revision"] | length > 0)'

stack_manifest() {
    podman "${podman_args[@]}" run --rm --pull=never --network=none --entrypoint bash "$1" -euo pipefail -c '
        rpm -qa --queryformat "%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n" |
            sort | grep -E "^(kernel[^ ]*|mesa[^ ]*|vulkan-loader|steam|steam-devices|mutter|gnome-shell|terra-gamescope[^ ]*|terra-mangohud|terra-wireplumber|xorg-x11-server-Xwayland|terra-xorg-x11-server-Xwayland) "
        sha256sum /usr/lib/modules/*/vmlinuz
    '
}
base_manifest="$(stack_manifest "$base")"
up_manifest="$(stack_manifest "$image")"
diff -u <(printf '%s\n' "$base_manifest") <(printf '%s\n' "$up_manifest")
echo 'Inherited gaming stack and kernel binary match the pinned base.'
