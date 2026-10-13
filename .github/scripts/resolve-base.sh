#!/usr/bin/bash
# Refresh only the runner's checkout; every subsequent use is digest-pinned.
set -euo pipefail
mode="${1:?Usage: resolve-base.sh pinned|refresh}"
: "${FEDORA_VERSION:?}" "${GITHUB_ENV:?}" "${GITHUB_STEP_SUMMARY:?}"
base=$(awk '/^FROM ghcr.io\/ublue-os\/bazzite-gnome:/ {print $2}' Containerfile)
[[ "$base" =~ ^ghcr.io/ublue-os/bazzite-gnome:stable@sha256:[a-f0-9]{64}$ ]]
case "$mode" in
    pinned) ;;
    refresh)
        digest=$(skopeo inspect --no-tags --format '{{.Digest}}' "docker://${base%@*}")
        [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
        base="${base%@*}@${digest}"
        ;;
    *) exit 1 ;;
esac
cosign verify --key keys/bazzite.pub --new-bundle-format=false "$base"
podman pull "$base"
actual=$(podman run --rm --pull=never --network=none --entrypoint rpm "$base" -E '%fedora')
if [[ "$actual" != "$FEDORA_VERSION" ]]; then
    echo "Refusing upstream Fedora ${actual}; approved build major is ${FEDORA_VERSION}." >&2
    exit 1
fi
# Existing build and smoke-test code reads this same immutable reference.
sed -i "s|^FROM ghcr.io/ublue-os/bazzite-gnome:.* AS base$|FROM ${base} AS base|" Containerfile
[[ "$(awk '/^FROM ghcr.io\/ublue-os\/bazzite-gnome:/ {print $2}' Containerfile)" == "$base" ]]
printf 'BASE_DIGEST=%s\n' "${base##*@}" >> "$GITHUB_ENV"
printf 'Verified Fedora %s upstream: %s\n' "$actual" "$base" >> "$GITHUB_STEP_SUMMARY"
