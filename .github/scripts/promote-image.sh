#!/usr/bin/bash
# Shared by daily publication and the manual, exact-digest release workflow.
#   CHANNEL=stable-N  writes stable-N, then the N alias; the image must be Fedora N.
#   CHANNEL=latest    writes latest; automatic updates only move it forward in Fedora.
set -euo pipefail
# Failures inside $(verify_image ...) must abort, not return partial output.
shopt -s inherit_errexit
mode="${1:?Usage: promote-image.sh automatic|manual}"
: "${DIGEST:?}" "${REPOSITORY:?}" "${CHANNEL:?}" "${REGISTRY_AUTH_FILE:?}"
[[ "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]
readonly upstream=ghcr.io/ublue-os/bazzite-gnome
case "$CHANNEL" in
    latest)
        required_major=''
        base_name="${upstream}:stable"
        tags=(latest)
        ;;
    stable-*)
        [[ "$CHANNEL" =~ ^stable-([0-9]+)$ ]]
        required_major="${BASH_REMATCH[1]}"
        base_name="${upstream}:${CHANNEL}"
        tags=("$CHANNEL" "$required_major")
        ;;
    *) exit 1 ;;
esac

# Prints the verified image's Fedora major. $2 is the base.name it must carry;
# empty skips that check (manual exceptions such as a Silverblue recovery).
verify_image() {
    local digest="$1" expected_base="$2"
    [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
    cosign verify --key cosign.pub --new-bundle-format=false "${REPOSITORY}@${digest}" > /dev/null
    skopeo inspect --config --authfile "$REGISTRY_AUTH_FILE" "docker://${REPOSITORY}@${digest}" |
        jq -er --arg major "$required_major" --arg base "$expected_base" '.config.Labels |
            select(.["org.opencontainers.image.title"] == "Up" and
                   .["containers.bootc"] == "1" and
                   ($base == "" or (.["org.opencontainers.image.base.name"] // "" | test($base)))) |
            (.["org.opencontainers.image.version"] // "" | capture("^(?<m>[0-9]+)[-.]").m) |
            select($major == "" or . == $major)'
}

# Regex for any signed Bazzite GNOME build of Up, including the legacy floating tag.
readonly any_bazzite='^ghcr\.io/ublue-os/bazzite-gnome:stable(-[0-9]+)?$'
case "$mode" in
    automatic)
        candidate_major=$(verify_image "$DIGEST" "^${base_name//./\\.}$")
        if previous=$(skopeo inspect --authfile "$REGISTRY_AUTH_FILE" --no-tags \
            --format '{{.Digest}}' "docker://${REPOSITORY}:${tags[0]}"); then
            # The previous image must already be Bazzite: an opt-in alone can
            # never perform the Silverblue migration or replace a recovery.
            previous_major=$(verify_image "$previous" "$any_bazzite")
            if ((candidate_major < previous_major)); then
                printf 'Refusing to move %s back from Fedora %s to %s.\n' \
                    "${tags[0]}" "$previous_major" "$candidate_major" >&2
                exit 1
            fi
        elif [[ "$CHANNEL" == latest ]]; then
            # latest is the bootstrap gate: its first Bazzite image is manual.
            echo 'No published latest to update; promote it manually first.' >&2
            exit 1
        fi
        ;;
    manual) verify_image "$DIGEST" '' > /dev/null ;;
    *) exit 1 ;;
esac
# All validation precedes moving tags. Update the channel tag first, using the
# same signed digest, with the existing digest-preserving registry copy mechanism.
for tag in "${tags[@]}"; do
    skopeo copy --preserve-digests --authfile "$REGISTRY_AUTH_FILE" \
        "docker://${REPOSITORY}@${DIGEST}" "docker://${REPOSITORY}:${tag}"
    actual=$(skopeo inspect --authfile "$REGISTRY_AUTH_FILE" --format '{{.Digest}}' \
        "docker://${REPOSITORY}:${tag}")
    [[ "$actual" == "$DIGEST" ]]
done
echo "Promoted verified image to ${tags[*]}: ${REPOSITORY}@${DIGEST}" >> "${GITHUB_STEP_SUMMARY:?}"
