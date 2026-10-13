#!/usr/bin/bash
# Image composition only. Never execute this script on a deployed host.
set -euo pipefail

: "${IMAGE_REPOSITORY:?}" "${IMAGE_VERSION:?}" "${IMAGE_REVISION:?}"
[[ "$IMAGE_REPOSITORY" =~ ^ghcr\.io/[a-z0-9._-]+/up$ ]]
[[ "$IMAGE_VERSION" =~ ^[a-zA-Z0-9._-]+$ ]]
[[ "$IMAGE_REVISION" =~ ^[a-zA-Z0-9._-]+$ ]]

# Keep upstream information for comparison without advertising its update target.
install -d /usr/share/up
cp /usr/share/ublue-os/image-info.json /usr/share/up/base-image-info.json
jq --arg vendor "${IMAGE_REPOSITORY#ghcr.io/}" \
    --arg ref "ostree-image-signed:docker://${IMAGE_REPOSITORY}" \
    --arg version "$IMAGE_VERSION" \
    '."image-name" = "up" | ."image-vendor" = ($vendor | split("/")[0]) |
     ."image-ref" = $ref | ."image-tag" = "latest" | ."image-branch" = "latest" |
     .version = $version | ."version-pretty" = $version' \
    /usr/share/up/base-image-info.json > /usr/share/ublue-os/image-info.json

# Trust only this repository with Up's existing key; keep other scopes intact.
install -Dm0644 /ctx/up.pub /etc/pki/containers/up.pub
jq --arg repository "$IMAGE_REPOSITORY" \
    '.transports.docker[$repository] = [{"type":"sigstoreSigned",
      "keyPath":"/etc/pki/containers/up.pub",
      "signedIdentity":{"type":"matchRepository"}}]' \
    /etc/containers/policy.json > /tmp/up-policy.json
install -m0644 /tmp/up-policy.json /etc/containers/policy.json
install -d /etc/containers/registries.d
printf 'docker:\n  %s:\n    use-sigstore-attachments: true\n' "$IMAGE_REPOSITORY" \
    > /etc/containers/registries.d/up.yaml

# Keep ID/VARIANT_ID compatible with inherited tools. Give the derived initramfs
# its own identity so hibernation cannot confuse it with the base image.
sed -i -e 's/^NAME=.*/NAME="Up"/' -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Up"/' \
    -e "s/^IMAGE_ID=.*/IMAGE_ID=\"up-${IMAGE_VERSION}-${IMAGE_REVISION}\"/" \
    -e "s/^BOOTLOADER_NAME=.*/BOOTLOADER_NAME=\"Up ${IMAGE_VERSION}\"/" \
    -e "s/^BUILD_ID=.*/BUILD_ID=\"${IMAGE_VERSION}\"/" \
    /usr/lib/os-release
printf 'Up release 44 (GNOME)\n' > /etc/system-release

# Up manages user apps without Bazzite's global Flatpak permission overrides or
# first-login dconf/group changes. Masks also prevent inherited presets starting them.
systemctl mask bazzite-flatpak-manager.service
systemctl --global mask bazzite-user-setup.service
# The copied 00-up-admin-helpers.rules also overrides permissive action XML.
rm -f /usr/share/polkit-1/rules.d/20-privileged-ruser.rules \
    /usr/share/polkit-1/rules.d/90-corectrl.rules \
    /usr/share/polkit-1/rules.d/30-waydroid.rules \
    /etc/polkit-1/rules.d/50-efibootmgr.rules

# Do not inherit a speculative global relaxation of split-lock mitigation.
install -d /etc/sysctl.d
ln -sf /dev/null /etc/sysctl.d/60-kernel.conf

# Preserve Up's GNOME defaults; do not enable upstream cosmetic extensions,
# custom shortcuts, or Steam autostart for newly created users.
rm -f /usr/share/glib-2.0/schemas/zz0-*-bazzite-desktop-silverblue-*.gschema.override \
    /etc/skel/.config/autostart/steam.desktop \
    /etc/skel/.config/autostart/bazzite-portal.desktop \
    /usr/share/applications/waydroid-container-restart.desktop
glib-compile-schemas /usr/share/glib-2.0/schemas

# Keep one upstream update orchestrator. No new updater or scheduler is introduced.
systemctl disable bootc-fetch-apply-updates.timer rpm-ostreed-automatic.timer
systemctl enable uupd.timer
# The upstream Cockpit entry can launch a container even without Cockpit RPMs.
systemctl mask cockpit.service
# Hardware-specific tools remain available without starting on every desktop.
systemctl disable fw-fanctrl.service scx_loader.service
# DisplayLink is optional upstream; retain it when supplied by the base.
# An installed package with a missing/broken unit must still fail composition.
if rpm -q --quiet displaylink; then
    systemctl disable displaylink.service
fi

# Record the composed result, not guessed package versions.
rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > /usr/share/up/packages.txt
cp /tmp/packages.json /usr/share/up/packages.json
dnf5 repo list --enabled > /usr/share/up/enabled-repositories.txt

# Rebuild only because image identity changed; kernel/module selection stays upstream.
kernel_release="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core)"
[[ "$kernel_release" != *$'\n'* ]]
mkdir -p /var/roothome
DRACUT_NO_XATTR=1 dracut --tmpdir /tmp --no-hostonly --kver "$kernel_release" --reproducible \
    --zstd --add ostree --add fido2 --force "/usr/lib/modules/${kernel_release}/initramfs.img"
chmod 0600 "/usr/lib/modules/${kernel_release}/initramfs.img"
