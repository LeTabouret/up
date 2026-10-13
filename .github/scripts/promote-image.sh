#!/usr/bin/bash
# Shared by daily publication and the manual, exact-digest release workflow.
set -euo pipefail
mode="${1:?Usage: promote-image.sh automatic|manual}"
: "${DIGEST:?}" "${REPOSITORY:?}" "${FEDORA_VERSION:?}" "${REGISTRY_AUTH_FILE:?}"
[[ "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]
[[ "$FEDORA_VERSION" =~ ^[0-9]+$ ]]

verify_image() {
    local digest="$1"
    [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
    cosign verify --key cosign.pub --new-bundle-format=false "${REPOSITORY}@${digest}"
    skopeo inspect --config --authfile "$REGISTRY_AUTH_FILE" "docker://${REPOSITORY}@${digest}" |
        jq -e --arg major "$FEDORA_VERSION" --arg mode "$mode" '.config.Labels |
            .["org.opencontainers.image.title"] == "Up" and
            .["containers.bootc"] == "1" and
            ($mode == "manual" or
             .["org.opencontainers.image.base.name"] == "ghcr.io/ublue-os/bazzite-gnome:stable") and
            (.["org.opencontainers.image.version"] | startswith($major + "-"))'
}

case "$mode" in
    automatic)
        # An opt-in alone cannot perform the Silverblue migration. The operator
        # must first promote a tested Bazzite image of this major manually.
        [[ "${BAZZITE_AUTO_PUBLISH_FEDORA:-}" == "$FEDORA_VERSION" ]]
        previous=$(skopeo inspect --authfile "$REGISTRY_AUTH_FILE" --no-tags --format '{{.Digest}}' \
            "docker://${REPOSITORY}:latest")
        verify_image "$previous"
        ;;
    manual) ;;
    *) exit 1 ;;
esac
verify_image "$DIGEST"
# All validation precedes moving tags. Update latest last, using the same signed
# digest, with the existing digest-preserving registry copy mechanism.
for tag in "$FEDORA_VERSION" latest; do
    skopeo copy --preserve-digests --authfile "$REGISTRY_AUTH_FILE" \
        "docker://${REPOSITORY}@${DIGEST}" "docker://${REPOSITORY}:${tag}"
    actual=$(skopeo inspect --authfile "$REGISTRY_AUTH_FILE" --format '{{.Digest}}' \
        "docker://${REPOSITORY}:${tag}")
    [[ "$actual" == "$DIGEST" ]]
done
echo "Promoted verified image: ${REPOSITORY}@${DIGEST}" >> "${GITHUB_STEP_SUMMARY:?}"
