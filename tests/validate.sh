#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

jq empty packages.json renovate.json
bash -n build.sh customize.sh usr/libexec/ublue-user-flatpak-manager \
    usr/libexec/up-verify-image tests/*.sh .github/scripts/*.sh
shellcheck build.sh customize.sh usr/libexec/ublue-user-flatpak-manager \
    usr/libexec/up-verify-image tests/*.sh .github/scripts/*.sh
shfmt --diff --indent 4 --case-indent --space-redirects build.sh customize.sh \
    usr/libexec/ublue-user-flatpak-manager usr/libexec/up-verify-image tests/*.sh .github/scripts/*.sh
tests/test-package-removal.sh
tests/test-flatpak-manager.sh
tests/test-json-validation.sh
python3 tests/test-release.py
python3 tests/test-policy.py
python3 tests/test-diagnostics.py
node tests/test-polkit.js

echo "Repository validation passed."
