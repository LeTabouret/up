#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

jq --exit-status empty packages.json renovate.json
bash -n build.sh usr/libexec/ublue-user-flatpak-manager tests/*.sh
shellcheck build.sh usr/libexec/ublue-user-flatpak-manager tests/*.sh
shfmt --diff --indent 4 --case-indent --space-redirects build.sh usr/libexec/ublue-user-flatpak-manager tests/*.sh
tests/test-package-removal.sh
tests/test-flatpak-manager.sh

echo "Repository validation passed."
