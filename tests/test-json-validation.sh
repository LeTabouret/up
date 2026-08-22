#!/usr/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

jq empty "${repo_root}/packages.json"
jq empty "${repo_root}/renovate.json"

printf '{ malformed json\n' >"${test_root}/malformed.json"
if jq empty "${test_root}/malformed.json" 2>/dev/null; then
    echo "Malformed JSON unexpectedly passed validation." >&2
    exit 1
fi

echo "JSON validation tests passed."
