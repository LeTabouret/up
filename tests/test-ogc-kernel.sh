#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
containerfile="${repo_root}/Containerfile"
installer="${repo_root}/install-ogc-kernel.sh"
renovate_config="${repo_root}/renovate.json"
workflow="${repo_root}/.github/workflows/build.yml"

grep -Eq '^FROM ghcr\.io/ublue-os/akmods:ogc-44@sha256:[a-f0-9]{64} AS ogc-akmods$' "$containerfile"
grep -Fq '# renovate: datasource=docker depName=ghcr.io/ublue-os/akmods versioning=docker' "$containerfile"
grep -Fq 'from=ogc-akmods,source=/kernel-rpms,target=/tmp/kernel-rpms,ro' "$containerfile"
grep -Fq '/ctx/install-ogc-kernel.sh' "$containerfile"
grep -Fq 'set -euo pipefail' "$installer"
grep -Fq 'trap restore_kernel_hooks EXIT' "$installer"
# These assertions intentionally match literal array expansions in the script.
# shellcheck disable=SC2016
grep -Fq 'rpm --erase --nodeps -- "${installed[@]}"' "$installer"
# shellcheck disable=SC2016
grep -Fq 'dnf5 -y install "${ogc_rpms[@]}"' "$installer"
grep -Fq 'kernel-modules-* | kernel-devel | kernel-devel-*' "$installer"
grep -Fq 'Expected exactly one OGC kernel release' "$installer"
grep -Fq 'Kernel package was not supplied by the pinned OGC artifact' "$installer"
# shellcheck disable=SC2016
grep -Fq 'dnf5 versionlock add "${ogc_packages[@]}"' "$installer"
grep -Fq '/usr/share/up/ogc-kernel-packages' "$installer"
grep -Fq '"matchUpdateTypes": ["digest"]' "$renovate_config"
grep -Fq '"automergeType": "pr"' "$renovate_config"
grep -Fq '"ghcr.io/ublue-os/akmods"' "$renovate_config"
grep -Fq '"ghcr.io/ublue-os/silverblue-main"' "$renovate_config"
if grep -Fq '"ignoreTests": true' "$renovate_config"; then
    echo 'Renovate must not ignore CI for trusted image automerge.' >&2
    exit 1
fi
grep -Fq 'mapfile -t packages </usr/share/up/ogc-kernel-packages' "$workflow"
grep -Fq 'find /boot -mindepth 1 -delete' "$installer"
grep -Fq 'bootc container lint' "$containerfile"

echo 'OGC kernel integration tests passed.'
