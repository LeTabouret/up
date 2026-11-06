#!/usr/bin/bash
# Refresh only the runner's checkout; every subsequent use is digest-pinned.
#   pinned          use the committed FROM pin (pull requests)
#   refresh CHANNEL resolve the channel's upstream tag once:
#                   stable-N -> bazzite-gnome:stable-N, which must be Fedora N
#                   latest   -> bazzite-gnome:stable, whichever Fedora it carries
set -euo pipefail
mode="${1:?Usage: resolve-base.sh pinned | refresh stable-N|latest}"
channel="${2:-}"
: "${GITHUB_ENV:?}" "${GITHUB_STEP_SUMMARY:?}"
readonly upstream=ghcr.io/ublue-os/bazzite-gnome
base=$(awk '/^FROM ghcr.io\/ublue-os\/bazzite-gnome:/ {print $2}' Containerfile)
[[ "$base" =~ ^ghcr\.io/ublue-os/bazzite-gnome:(stable(-[0-9]+)?)@sha256:[a-f0-9]{64}$ ]]
tag="${BASH_REMATCH[1]}"
case "$mode" in
    pinned)
        [[ -z "$channel" ]]
        ;;
    refresh)
        case "$channel" in
            latest) tag=stable ;;
            stable-*)
                [[ "$channel" =~ ^stable-[0-9]+$ ]]
                tag="$channel"
                ;;
            *) exit 1 ;;
        esac
        digest=$(skopeo inspect --no-tags --format '{{.Digest}}' "docker://${upstream}:${tag}")
        [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
        base="${upstream}:${tag}@${digest}"
        ;;
    *) exit 1 ;;
esac
[[ "$tag" == stable ]] && channel=latest || channel="$tag"
cosign verify --key keys/bazzite.pub --new-bundle-format=false "$base"
podman pull "$base"
actual=$(podman run --rm --pull=never --network=none --entrypoint rpm "$base" -E '%fedora')
if [[ ! "$actual" =~ ^[0-9]+$ ]]; then
    echo "Upstream ${base} reported no Fedora release." >&2
    exit 1
fi
# A per-major stream must never carry another major. The rolling channel may.
if [[ "$tag" =~ ^stable-([0-9]+)$ && "$actual" != "${BASH_REMATCH[1]}" ]]; then
    echo "Refusing upstream Fedora ${actual} for ${upstream}:${tag}." >&2
    exit 1
fi
# Existing build and smoke-test code reads this same immutable reference.
sed -i "s|^FROM ghcr.io/ublue-os/bazzite-gnome:.* AS base$|FROM ${base} AS base|" Containerfile
[[ "$(awk '/^FROM ghcr.io\/ublue-os\/bazzite-gnome:/ {print $2}' Containerfile)" == "$base" ]]
{
    printf 'BASE_DIGEST=%s\n' "${base##*@}"
    printf 'UP_BASE_NAME=%s\n' "${upstream}:${tag}"
    printf 'UP_CHANNEL=%s\n' "$channel"
    printf 'UP_FEDORA_MAJOR=%s\n' "$actual"
} >> "$GITHUB_ENV"
printf 'Verified Fedora %s upstream for channel %s: %s\n' "$actual" "$channel" "$base" >> "$GITHUB_STEP_SUMMARY"
