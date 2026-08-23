#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

jq empty packages.json renovate.json
bash -n build.sh install-ogc-kernel.sh usr/libexec/ublue-user-flatpak-manager \
    usr/libexec/ublue-verify-ogc-boot tests/*.sh
shellcheck build.sh install-ogc-kernel.sh usr/libexec/ublue-user-flatpak-manager \
    usr/libexec/ublue-verify-ogc-boot tests/*.sh
shfmt --diff --indent 4 --case-indent --space-redirects build.sh install-ogc-kernel.sh \
    usr/libexec/ublue-user-flatpak-manager usr/libexec/ublue-verify-ogc-boot tests/*.sh
tests/test-package-removal.sh
tests/test-flatpak-manager.sh
tests/test-json-validation.sh
tests/test-ogc-kernel.sh

echo "Repository validation passed."
